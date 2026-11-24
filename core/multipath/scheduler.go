package multipath

import (
	"sync"
)

type InterfaceMetrics struct {
	Name         string
	SpeedBytesSec int64
	IsAlive      bool
	BytesCarried int64
}

type BlockAssignment struct {
	BlockIndex int
	IfaceName  string
}

type TransferJob struct {
	ID              string
	TotalBlocks     int
	BlockSizeBytes  int64
	CompletedBlocks int
	AssignedBlocks  map[int]string // blockIndex -> ifaceName
	CompletedMap    map[int]bool
	IsComplete      bool
}

// Scheduler distributes file blocks across available interfaces (Plexo multipath model, Section 5.7).
type Scheduler struct {
	mu         sync.RWMutex
	interfaces map[string]*InterfaceMetrics
	transfers  map[string]*TransferJob
}

func NewScheduler() *Scheduler {
	return &Scheduler{
		interfaces: make(map[string]*InterfaceMetrics),
		transfers:  make(map[string]*TransferJob),
	}
}

func (s *Scheduler) AddInterface(name string, speedBytesSec int64) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.interfaces[name] = &InterfaceMetrics{
		Name:          name,
		SpeedBytesSec: speedBytesSec,
		IsAlive:       true,
		BytesCarried:  0,
	}
}

func (s *Scheduler) FailInterface(name string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if iface, exists := s.interfaces[name]; exists {
		iface.IsAlive = false
	}

	// Return in-flight blocks assigned to the failed interface back to the unallocated pool
	for _, job := range s.transfers {
		if job.IsComplete {
			continue
		}
		for bIdx, assignedIface := range job.AssignedBlocks {
			if assignedIface == name && !job.CompletedMap[bIdx] {
				delete(job.AssignedBlocks, bIdx)
			}
		}
	}
}

func (s *Scheduler) InitTransfer(transferID string, totalBlocks int, blockSize int64) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.transfers[transferID] = &TransferJob{
		ID:             transferID,
		TotalBlocks:    totalBlocks,
		BlockSizeBytes: blockSize,
		AssignedBlocks: make(map[int]string),
		CompletedMap:   make(map[int]bool),
		IsComplete:     false,
	}
}

// DispatchNextBlocks assigns next unallocated blocks weighted by interface throughput.
func (s *Scheduler) DispatchNextBlocks(transferID string, count int) []BlockAssignment {
	s.mu.Lock()
	defer s.mu.Unlock()

	job, exists := s.transfers[transferID]
	if !exists || job.IsComplete {
		return nil
	}

	// Collect active interfaces
	var activeIfaces []*InterfaceMetrics
	var totalSpeed int64
	for _, iface := range s.interfaces {
		if iface.IsAlive {
			activeIfaces = append(activeIfaces, iface)
			totalSpeed += iface.SpeedBytesSec
		}
	}

	if len(activeIfaces) == 0 {
		return nil
	}

	var assignments []BlockAssignment
	assigned := 0

	for i := 0; i < job.TotalBlocks && assigned < count; i++ {
		if job.CompletedMap[i] {
			continue
		}
		if _, inFlight := job.AssignedBlocks[i]; inFlight {
			continue
		}

		// Weighted selection: pick faster interface with higher probability
		picked := activeIfaces[assigned%len(activeIfaces)]
		// If fastest interface exists, favor it
		for _, candidate := range activeIfaces {
			if candidate.SpeedBytesSec > picked.SpeedBytesSec && (assigned%2 == 0) {
				picked = candidate
			}
		}

		job.AssignedBlocks[i] = picked.Name
		assignments = append(assignments, BlockAssignment{
			BlockIndex: i,
			IfaceName:  picked.Name,
		})
		assigned++
	}

	return assignments
}

func (s *Scheduler) MarkBlockComplete(transferID string, blockIndex int, ifaceName string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	job, exists := s.transfers[transferID]
	if !exists || job.CompletedMap[blockIndex] {
		return
	}

	job.CompletedMap[blockIndex] = true
	job.CompletedBlocks++
	delete(job.AssignedBlocks, blockIndex)

	if iface, exists := s.interfaces[ifaceName]; exists {
		iface.BytesCarried += job.BlockSizeBytes
	}

	if job.CompletedBlocks >= job.TotalBlocks {
		job.IsComplete = true
	}
}

func (s *Scheduler) GetTransferStatus(transferID string) TransferJob {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if job, exists := s.transfers[transferID]; exists {
		return *job
	}
	return TransferJob{}
}

func (s *Scheduler) GetInterfaceAccounting() map[string]int64 {
	s.mu.RLock()
	defer s.mu.RUnlock()

	res := make(map[string]int64)
	for name, iface := range s.interfaces {
		res[name] = iface.BytesCarried
	}
	return res
}
