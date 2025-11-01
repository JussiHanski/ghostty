#!/bin/bash

# Display welcome wizard in Ghostty terminal

WIZARD_IMAGE="${HOME}/.config/ghostty/wizard.png"

if [ -f "$WIZARD_IMAGE" ]; then
    # Display using kitty graphics protocol for crisp image rendering
    chafa --format=kitty --size=40x20 "$WIZARD_IMAGE" 2>/dev/null || \
    chafa --format=symbols --size=40x20 "$WIZARD_IMAGE"
fi
