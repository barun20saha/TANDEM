package pal_android

import (
	"log"
	"sync"
)

var (
	engineActive bool
	mu           sync.Mutex
)

// StartEngine starts the embedded sync engine.
func StartEngine(configPath string) int {
	mu.Lock()
	defer mu.Unlock()

	log.Printf("[Android PAL] Tandem engine starting with config path: %s", configPath)
	engineActive = true
	return 0
}

// StopEngine stops the embedded sync engine.
func StopEngine() int {
	mu.Lock()
	defer mu.Unlock()

	log.Printf("[Android PAL] Tandem engine stopping...")
	engineActive = false
	return 0
}

// IsEngineActive checks if the engine is currently running.
func IsEngineActive() int {
	mu.Lock()
	defer mu.Unlock()

	if engineActive {
		return 1
	}
	return 0
}
