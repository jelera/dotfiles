#!/bin/bash
###############################################################################
#         Name: init.sh
#        Usage: ./init.sh
#
#  Description: Simple script to autocreate the symlinks for my dotfiles and
#               copy some helper programs to /usr/local/bin
#
# Last Updated: Tue 10 Mar 2020 09:34:37 PM CDT
#
#   Maintainer: Jose Elera (https://github.com/jelera)
#
#      License: MIT
#               Copyright (c) 2014 Jose Elera Campana
#
#               Permission is hereby granted, free of charge, to any person
#               obtaining a copy of this software and associated documentation
#               files (the "Software"), to deal in the Software without
#               restriction, including without limitation the rights to use,
#               copy, modify, merge, publish, distribute, sublicense, and/or
#               sell copies of the Software, and to permit persons to whom the
#               Software is furnished to do so, subject to the following
#               conditions:
#
#               The above copyright notice and this permission notice shall be
#               included in all copies or substantial portions of the Software.
#
#               THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#               EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#               OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#               NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#               HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#               WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#               FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#               OTHER DEALINGS IN THE SOFTWARE.
###############################################################################
#############################################################################//
#
# => HELPER FUNCTIONS
#
#############################################################################//

function color_echo(){
# Usage  : color_echo "string" color
# Credit : http://stackoverflow.com/a/23006365/428786
	local exp=$1;
	local color=$2;
	if ! [[ $color =~ ^[0-9]$ ]] ; then
	case $(echo "$color" | tr '[:upper:]' '[:lower:]') in
		black) color=0 ;;
		red) color=1 ;;
		green) color=2 ;;
		yellow) color=3 ;;
		blue) color=4 ;;
		magenta) color=5 ;;
		cyan) color=6 ;;
	white|*) color=7 ;; # white or invalid color
	esac
	fi

	tput setaf $color;
	printf "\n%s\n" "$exp"
	tput sgr0;
}

function figlet_echo(){
	local exp=$1;
	local color=$2;
	if ! [[ $color =~ ^[0-9]$ ]] ; then
		case $(echo "$color" | tr '[:upper:]' '[:lower:]') in
			black) color=0 ;;
			red) color=1 ;;
			green) color=2 ;;
			yellow) color=3 ;;
			blue) color=4 ;;
			magenta) color=5 ;;
			cyan) color=6 ;;
			white|*) color=7 ;; # white or invalid color
		esac
	fi

	tput setaf $color;
	printf "\n%s" "$exp"
	tput sgr0;
}


echo
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░" green
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░" green
figlet_echo "░░░▀█▀░█▀█░▀█▀░▀█▀░░░░█▀▀░█░█░░░" green
figlet_echo "░░░░█░░█░█░░█░░░█░░░░░▀▀█░█▀█░░░" green
figlet_echo "░░░▀▀▀░▀░▀░▀▀▀░░▀░░▀░░▀▀▀░▀░▀░░░" green
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░" green
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░\n\n" green
echo
color_echo "---------------------------------------" red
color_echo "|                                     |" red
color_echo "|  MAKE SURE YOU CLONE THIS GIT REPO  |" red
color_echo "|   INSIDE THE ~/.config DIRECTORY    |" red
color_echo "|                                     |" red
color_echo "---------------------------------------" red
sleep 2


##---------------------------------------------------------------------------//
##
## => BACKUP OLD DOTFILES
##
##---------------------------------------------------------------------------//
echo
color_echo "Backup the old dotfiles (up to 2 times) to ~/.dotfiles.old ..." cyan
if [ -d ~/.dotfiles.old ]; then
	if [ -d /tmp/old.dotfiles ]; then
		rm -rf /tmp/old.dotfiles
	fi
	mv -f ~/.dotfiles.old /tmp/old.dotfiles
fi
mkdir -p ~/.dotfiles.old

if [[ -f ~/.profile || -L ~/.profile ]]; then
	mv -f ~/.profile ~/.dotfiles.old
fi
if [[ -f ~/.bashrc || -L ~/.bashrc ]]; then
	mv -f ~/.bashrc ~/.dotfiles.old
fi
if [[ -f ~/.zshrc || -L ~/.zshrc ]]; then
	mv -f ~/.zshrc ~/.dotfiles.old
fi
if [[ -f ~/.gitconfig || -L ~/.gitconfig ]]; then
	mv -f ~/.gitconfig ~/.dotfiles.old
fi
if [[ -f ~/.gitignore_global || -L ~/.gitignore_global ]]; then
	mv -f ~/.gitignore_global ~/.dotfiles.old
fi
if [[ -f ~/.tmux.conf || -L ~/.tmux.conf ]]; then
	mv -f ~/.tmux.conf ~/.dotfiles.old
fi
if [[ -f ~/.vimrc || -L ~/.vimrc ]]; then
	mv -f ~/.vimrc ~/.dotfiles.old
fi
if [[ -d ~/.vim || -L ~/.vim ]]; then
	mv -f ~/.vim ~/.dotfiles.old
fi
if [[ -d ~/.bin || -L ~/.bin ]]; then
	mv -f ~/.bin ~/.dotfiles.old
fi
if [[ -d ~/.oh-my-zsh || -L ~/.oh-my-zsh ]]; then
	mv -f ~/.oh-my-zsh ~/.dotfiles.old
fi

echo
color_echo "You can find them at ~/.dotfiles.old" cyan
sleep 1.5


##---------------------------------------------------------------------------//
##
## => INSTALL OH-MY-ZSH
##
##---------------------------------------------------------------------------//
echo
color_echo "Installing oh-my-zsh ..." cyan
# git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh

# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O /tmp/ohmyzsh-install.sh

sleep 1


##---------------------------------------------------------------------------//
##
## => CREATING THE SYMLINKS
##
##---------------------------------------------------------------------------//
echo
color_echo "Creating the Symlinks ..." cyan
ln -s "$HOME"/.config/dotfiles/bin                  "$HOME"/.bin
ln -s "$HOME"/.config/dotfiles/bash/bashrc          "$HOME"/.bashrc
ln -s "$HOME"/.config/dotfiles/bash/bash_profile    "$HOME"/.profile

ln -s "$HOME"/.config/dotfiles/gitconfig/gitconfig  "$HOME"/.gitconfig
ln -s "$HOME"/.config/dotfiles/gitconfig/gitignore  "$HOME"/.gitignore_global

ln -s "$HOME"/.config/dotfiles/tmux/tmux.conf       "$HOME"/.tmux.conf

ln -s "$HOME"/.config/dotfiles/zsh/zshrc            "$HOME"/.zshrc
sleep 1

##---------------------------------------------------------------------------//
##
## => SETTING UP TMUX
##
##---------------------------------------------------------------------------//
echo
color_echo "Tmux Plugin Manager ..." cyan
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

sleep 1


##---------------------------------------------------------------------------//
##
## => SETTING UP VIM
##
##---------------------------------------------------------------------------//
echo
color_echo "---------------------------------------" yellow
color_echo "|                                      |" yellow
color_echo "|  Setting up Vim Configuration Files  |" yellow
color_echo "|                                      |" yellow
color_echo "----------------------------------------" yellow
echo
color_echo "Checking if dotvim repo is installed..." cyan
echo
color_echo "If it is... it will be moved to .dotfiles.old dir" red
sleep 2
if [[ -d ~/.config/dotfiles/vim || -L ~/.config/dotfiles/vim ]]; then
	mv -f ~/.config/dotfiles/vim ~/.dotfiles.old
fi

color_echo "Cloning my dotvim repo ..." cyan
# Cloning my dotvim repo and create the symlinks
git clone git@github.com:jelera/vimconfig.git ~/.config/dotfiles/vim
ln -s "$HOME"/.config/dotfiles/vim     "$HOME"/.vim

# Making the directories for backup, swap and undo
echo
color_echo "Making directories within .vim for backup, swap and undo ..." cyan
mkdir -p ~/.vim/.cache
mkdir -p ~/.vim/.cache/backup
mkdir -p ~/.vim/.cache/swap
mkdir -p ~/.vim/.cache/undo
mkdir -p ~/.vim/.cache/unite
mkdir -p ~/.vim/.cache/junk

# Install Vim-plug
echo
color_echo "Installing Vim Plug for managing Vim Plugins ..." cyan
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall
sleep 1


color_echo "Install the rest using this line" green
color_echo " Run this line as a regular user" green
echo
color_echo "cd ~/.config/dotfiles/install_scripts; sudo ./install_ubuntu_trusty.sh; ./install_patched_fonts.sh; ./install_rbenv_pyenv; ./install_atom_packages.sh; cd $HOME" yellow
echo
echo
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
figlet_echo "░░░▀█▀░█░█░█▀▀░░░█▀▀░█▀█░█▀▄░░░"
figlet_echo "░░░░█░░█▀█░█▀▀░░░█▀▀░█░█░█░█░░░"
figlet_echo "░░░░▀░░▀░▀░▀▀▀░░░▀▀▀░▀░▀░▀▀░░░░"
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
figlet_echo "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░"
echo
echo
sh /tmp/ohmyzsh-install.sh
