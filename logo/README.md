# Logo Generation Subsystem

This directory contains utility files for auto-generating the Balance logo (`logo.svg`).

## Architecture

*   **`logo_gen.pas`** – A specialized executable physics scene. It runs a deterministic macro-simulation that starts with a single lever, then adds bodies underneath to lift the lever off its triangular base

*   **`balance_wpfsvg.pas`** – A modified version of `balance_wpf.pas`. It converts real-time drawing commands into code to save the scene as an SVG file.

## Scope of Application

> [!IMPORTANT]
> The `balance_wpfsvg.pas` module **is not an official part of the core engine library**. It is a specialized utility designed for internal purposes only.

## Rebuilding the Logo

1. Open and run `logo_gen.pas` in PascalABC.NET.
2. Upon reaching the target frame, the system will automatically export a self-contained `logo.svg` into this folder. Required font will be embedded inside the file as Base64.
