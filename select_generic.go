// Copyright (c) 2020 Robert Clausecker <fuz@fuz.su>

// +build !amd64,!386
// +build !go1.16 !arm64

package pospop

// generic variants only
var count8funcs = []count8impl{{count8generic, "generic", true}}
var count16funcs = []count16impl{{count16generic, "generic", true}}
var count32funcs = []count32impl{{count32generic, "generic", true}}
var count64funcs = []count64impl{{count64generic, "generic", true}}
