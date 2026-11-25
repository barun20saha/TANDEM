//go:build cgo

package main

/*
#include <stdint.h>
#include <stdlib.h>
*/
import "C"

import "tandem/core/pal_android"

//export TandemStartEngine
func TandemStartEngine(configPath *C.char) C.int {
	return C.int(pal_android.StartEngine(C.GoString(configPath)))
}

//export TandemStopEngine
func TandemStopEngine() C.int {
	return C.int(pal_android.StopEngine())
}

//export TandemIsEngineActive
func TandemIsEngineActive() C.int {
	return C.int(pal_android.IsEngineActive())
}

func main() {}
