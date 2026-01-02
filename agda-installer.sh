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
    # Consigue el nombre de usuario ya existente
	name=$(whiptail --inputbox "Nombre de usuario de la cuenta" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Nombre de usuario no valido. Escribe un nombre de usuario que empiece por una letra, con solo letras minúsculas, - o _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "ADVERTENCIA" --yes-button "CONTINUA" \
			--no-button "Espera nwn..." \
			--yesno "El usuario \`$name\` ya existe en el sistema. AGDA puede instalar para un usuario ya existente, pero sobreescribirá cualquier configuración/dotfiles en la cuenta del usuario.\\n\\nAGDA NO sobreescribirá tus archivos de usuario, documentos, videos, etc., así que no te preocupes, solo haz click <CONTINUA> si no te importa que tu configuración se sobreescriba.\\n\\nNota también que AGDA cambiará la contraseña de $name a la que acabas de dar." 14 70
}

adduserandpass() {
	# Adds user `$name` to wheel
	whiptail --infobox "Añadiendo user a grupo wheel \"$name\"..." 7 50
	usermod -a -G wheel "$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	whiptail --infobox "Configurando directorio de repositorios \"$repodir\"..." 7 50
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
}

# Suponiendo que hubo una instalación de Arch a través del script de instalación de Arch
# y que ya tenemos instalados los siguientes paquetes:

installmain() {
    # Instalar paquetes
	whiptail --title "Instalación de AGDA" --infobox "Instalando \`$1\` ($n de $total). $1 $2" 9 70
    installpkg "$1"
}

aurinstall() {
	whiptail --title "Instalación de AGDA" \
		--infobox "Instalando \`$1\` ($n of $total) del AUR. $1 $2" 9 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

installfonts() {
    # Instalar fuentes
	whiptail --title "Instalación de AGDA" --infobox "Instalando fuentes ($n de $total). $1 $2" 9 70
    installpkg "$1"
}

getdotfiles() {
    git clone $dotsfilesrepo
    mv duandotfiles/.* ~/
}

installationloop() {
    # Loop to install all packages in progs.csv
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program; do
		n=$((n + 1))
		case "$tag" in
		    "A") aurinstall "$program" "$comment" ;;
		    "G") gitmakeinstall "$program" "$comment" ;;
		    *) maininstall "$program" "$comment" ;;
        esac
    done </tmp/progs.csv
}

setautomaticlogin() {
    # Set automatic login
    whiptail --title "AGDA" --infobox "Configurando login automático" 8 70
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    touch /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "[Service]" > /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=-/sbin/agetty --noreset --noclear --autologin $name \${TERM}" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
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

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Sudo sin contraseña para el usuario, para que el usuario pueda instalar paquetes
# en un entorno fakeroot para el AUR
trap 'rm -f /etc/sudoers.d/agda-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/agda-temp

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Instalacion de todos los paquetes en progs.csv
installationloop

# Hacer zsh el shell por defecto
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Hacer dash el enlace simbólico a sh por defecto
ln -sfT /bin/dash /bin/sh >/dev/null 2>&1

# Hacer sudoer para wheel sin contraseña para que pueda ejecutar comandos del sistema
# (como shutdown, reboot, etc.)
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-agda-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff,/usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-agda-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-agda-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf
