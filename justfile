# basically bootstraps anything but the flake out, even this justfile

clean:
    git sparse-checkout init --no-cone
    git sparse-checkout set '/*' '!README.md' '!LICENSE' '!justfile'
