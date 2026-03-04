# fpga-neural-synthesizer
FPGA Polyphonic Synthesizer with Neural Melody Generator

Base Wavetable Synthesizer (Lab 4) 
- Designed a master control unit state machine to handle interactive play, pause, and skip logic via button inputs.
- Built a song reader to systematically look up sequences of notes and durations from an internal song ROM.
- Implemented a note player to determine frequency step sizes by mapping incoming notes to a frequency ROM.
- Created a sine reader to calculate precise 48 kHz audio samples by utilizing a 1024-sample sine ROM.

Real-Time Waveform Display (Lab 5)
- Developed a wave capture module utilizing a finite state machine to buffer 256 incoming audio samples into RAM.
- Engineered a wave display module to synchronize dual-ported RAM read addresses with external VGA scanning coordinates.
- Implemented a double-buffering memory strategy to prevent visual tearing by splitting RAM addresses into alternating read and write blocks.
- Translated 11-bit X and 10-bit Y screen coordinates to accurately render real-time continuous waveforms on an 800x480 raster display.

Advanced Audio & Predictive Logic (Final Project Extensions) (In Progress) --> see Checkpoint 0 and 1
- Enabled polyphonic chords to play at least three simultaneous notes by combining multiple generated waveforms into a single audio output.
- Upgraded the waveform display with a color ROM to assign distinct colors to individual notes and render the combined chord waveform in white.
- Integrated a rewind function to traverse the song ROM backward and mirror the sine wave sampling process for reverse playback.
- Simulated distinct instruments by calculating and applying weighted sums of higher-frequency harmonics.
- Constructed a real-time neural network melody generator by hardcoding the weights of a pre-trained Python feed-forward model into Verilog hardware logic to autonomously predict note sequences.

Contributed by: Arif Khalfani Ismail and Berwyn Berwyn.