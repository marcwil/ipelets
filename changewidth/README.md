# Sync Minipage Widths – Ipelet

Synchronize the widths of multiple *minipage* text objects in [Ipe](https://ipe.otfried.org) by copying the width from the **primary** selection to every other selected minipage.

## Usage

**Sync width command:**
1. Select every minipage you want to resize.
2. Select the *reference* minipage **last** so it becomes the primary selection.
3. Run **Ipelets → Sync minipage widths → Sync widths**.
4. All secondary minipages adopt the reference width.

**Interactive tool:** like Ipe's default `Alt+W` but all selected minipages are
set to the desired width

## Installation

* Download sync\_minipage\_width.lua.
* Copy it into one of Ipe’s ipelet search paths, e.g. \~/.ipe/ipelets/ (Linux/macOS) or %APPDATA%\Ipe\ipelets (Windows).
* Restart Ipe or choose Help → Developer → Reload ipelets.

You’ll now find the ipelet under Ipelets → Sync minipage widths.
