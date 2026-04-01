# FPGA Polyphonic Synthesizer with Neural Melody Generator

Contributed by: Arif Ismail and Berwyn Berwyn

## Overview
This project implements a complete, hardware-level audio synthesizer and real-time waveform visualizer on an FPGA. Built as a cumulative progression, the system scales from a basic wavetable synthesizer to a multi-voice polyphonic instrument, culminating in a custom hardware neural network that autonomously predicts and generates musical note sequences.


## Part 1: Base Wavetable Synthesizer (Lab 4)
The foundational audio generation system built to read and synthesize predetermined sequences of notes.
* **MCU & Playback Control:** A master control unit state machine handles interactive play, pause, and mode switching logic.
* **Prioritized Song Reader:** Systematically reads instructions from an internal song ROM and assigns notes to the playback modules.
* **Note Player & Sine Readers:** Maps incoming notes to a frequency ROM to determine step sizes. Generates precise 48 kHz audio samples by stepping through a 1024-sample sine ROM.

## Part 2: Real-Time Waveform Display (Lab 5)
A hardware-level visualizer designed to render the generated audio signals in real-time on an external monitor.
* **Memory Synchronization:** Utilizes a finite state machine to buffer 256 incoming audio samples into RAM.
* **Double-Buffering Strategy:** Prevents visual tearing on the display by splitting read and write addresses into alternating memory blocks.
* **VGA Rendering:** Translates 11-bit X and 10-bit Y screen coordinates to accurately draw continuous waveforms on an 800x480 raster display.

## Part 3: Advanced Audio & Predictive Logic (Final Project Extensions)
Custom hardware extensions to introduce polyphony, reverse playback, and autonomous melody generation.
* **Polyphonic & Harmonic Synthesis:** Expanded the datapath to support four concurrent `note_player` modules (4-voice polyphony). Each module applies predetermined weights to calculated harmonics to simulate distinct physical instruments.
* **Multi-Wave Enhanced Display:** Orchestrates five distinct display modules to concurrently render the four individual chord notes (color-coded) alongside the combined resultant waveform (rendered in white "on top" via a priority arbiter).
* **Hardware Neural Network Melody Generator:** 
    * Implemented a custom two-layer feed-forward neural network hardcoded in Verilog (32 hidden neurons, 12 output neurons).
    * Pre-trained weights and biases are stored in ROMs using a 16-bit fixed-point representation (Q4.12 format).
    * Engineered a resource-optimized, 3-stage pipelined datapath that reuses a single multiplier and accumulator to execute thousands of multiply-and-accumulate (MAC) cycles with ReLU activation, calculating the next musical note autonomously.