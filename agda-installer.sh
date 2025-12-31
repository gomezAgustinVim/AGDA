#!/bin/sh

# VIHenvenido a mi mundo...

dotsfilesrepo="https://github.com/gomezAgustinVim/duandotfiles"
progsfile="https://raw.githubusercontent.com/gomezAgustinVim/AGDA/master/progs.csv"
fontlist="https://raw.githubusercontent.com/gomezAgustinVim/AGDA/master/fontlist.csv"
aurhelper="yay"

installpkg() {
    pacman -S --needed --noconfirm "$1" >/dev/null 2>&1
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
    whiptail --title "VIHenvenido a mi mundo de AGDA" \
        --msgbox "Este script instalará todos los paquetes que uso en Arch" 10 60

    whiptail --title "Importante" --yes-button "Continuar" \
        --no-button "Salir" \
        --yesno "¿Estás seguro de que quieres continuar?" 8 70
    }

# Debe correrse después de una instlación de Arch
# ya sea con el archinstall o manualmente

getuserandpass() {
	# Prompts user for new username and password.
	name=$(whiptail --inputbox "Nombre de usuario de la cuenta" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Nombre de usuario no valido. Escribe un nombre de usuario que empiece por una letra, con solo letras minúsculas, - o _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Contraseña" 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Reescribre la contraseña" 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Las contraseñas no coinciden.\\n\\nReescribe la contraseña" 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Reescribre la contraseña" 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "ADVERTENCIA" --yes-button "CONTINUA" \
			--no-button "Espera nwn..." \
			--yesno "El usuario \`$name\` ya existe en el sistema. AGDA puede instalar para un usuario ya existente, pero sobreescribirá cualquier configuración/dotfiles en la cuenta del usuario.\\n\\nAGDA NO sobreescribirá tus archivos de usuario, documentos, videos, etc., así que no te preocupes, solo haz click <CONTINUA> si no te importa que tu configuración se sobreescriba.\\n\\nNota también que AGDA cambiará la contraseña de $name a la que acabas de dar." 14 70
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	whiptail --infobox "Adding user \"$name\"..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

# Suponiendo que hubo una instalación de Arch a través del script de instalación de Arch
# y que ya tenemos instalados los siguientes paquetes:

installmain() {
    # Instalar paquetes
	whiptail --title "Instalación de AGDA" --infobox "Instalando \`$1\` ($n de $total). $1 $2" 9 70
    installpkg "$1"
}

installfonts() {
    # Instalar fuentes
	whiptail --title "Instalación de AGDA" --infobox "Instalando fuentes ($n de $total). $1 $2" 9 70
    installpkg "$1"
}

getdotfiles() {
    git clone $dotsfilesrepo
    mv duandotfiles/.config ~
}

# Script principal

for x in curl ca-certificates base-devel git ntp zsh dash; do
	whiptail --title "AGDA Instalación" \
		--infobox "Instalando \`$x\` requerido para instalar y configurar otros programas." 8 70
	installpkg "$x"
done

whiptail --title "AGDA Instalación" \
	--infobox "Sincronizando con el servidor de tiempo" 8 70
ntpd -q -g >/dev/null 2>&1

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Instalacion de todos los paquetes en progs.csv
installationloop

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"
