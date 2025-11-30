eval "$(starship init zsh)"

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh

. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"

fastfetch -c ~/.config/fastfetch/sample_2.jsonc
