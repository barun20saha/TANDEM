//go:build cgo

package pal_android

/*
#include <stdint.h>
#include <stdlib.h>
*/
import "C"

//export TandemStartEngine
func TandemStartEngine(configPath *C.char) C.int {
	return C.int(StartEngine(C.GoString(configPath)))
}

//export TandemStopEngine
func TandemStopEngine() C.int {
	return C.int(StopEngine())
}

//export TandemIsEngineActive
func TandemIsEngineActive() C.int {
	return C.int(IsEngineActive())
}
