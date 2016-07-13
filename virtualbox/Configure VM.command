#!/bin/bash

set -eu
IFS=$'\n'

export PATH="/usr/local/bin:/usr/bin:/bin"

RED="\e[1;91m"
GREEN="\e[1;92m"
BLUE="\e[1;34m"
YELLOW="\e[1;5;43m"
RESET="\e[0m"
HR="************************************************************************"

pak() {
  printf "press the any key to continue..."
  read -sn1
  exit
}

trap pak 1 2 3 6 9


printf "${BLUE}Cleaning the laboratory...${RESET}"
for vm in "Windows" "Windows 7" "JMP Genomics"; do
	VBoxManage unregistervm "${vm}" --delete 2>/dev/null || true
	rm -rf "${HOME}/VirtualBox VMs/${vm}" || true
done
printf "${BLUE}done\n${RESET}"

DISK="/Virtual Machines/Windows/Windows 7.vdi"
NAME="JMP Genomics"

if [[ ! -r "${DISK}" ]]; then
	printf "\n\n"
	printf "${RED}%s${RESET}\n" "${HR}"
	printf "${RED}%s${RESET}\n" "He's Dead Jim"
	printf "${RED}%s${RESET}\n" "${HR}"
	printf "\n\n"
	read -sn 1
fi

install -m 0755 -d "${HOME}/VirtualBox VMs"

printf "${BLUE}Raising the ligtning rod...\n${RESET}" "${USER:-odysseus}"
VBoxManage createvm --name "${NAME}" --ostype Windows7_64 --basefolder "${HOME}/VirtualBox VMs"  --register
VBoxManage storagectl    "${NAME}" --name "IDE"  --add ide  --controller PIIX4
VBoxManage storagectl    "${NAME}" --name "SATA" --add sata --controller IntelAHCI --portcount 1
VBoxManage storageattach "${NAME}" --storagectl IDE  --port 1 --device 0 --type dvddrive --medium emptydrive
VBoxManage storageattach "${NAME}" --storagectl SATA --port 0 --type hdd \
  --medium "${DISK}" --mtype immutable
VBoxManage modifyvm      "${NAME}" --memory 6144 --cpus 1 --pae off --vram 48 \
  --usb on --usbehci on --audio none \
  --nic1 nat --nictype1 virtio \
  --clipboard bidirectional --draganddrop hosttoguest
VBoxManage sharedfolder add "${NAME}" --name Desktop   --hostpath "${HOME}/Desktop"   --automount
VBoxManage sharedfolder add "${NAME}" --name Documents --hostpath "${HOME}/Documents" --automount
VBoxManage sharedfolder add "${NAME}" --name Downloads --hostpath "${HOME}/Downloads" --automount
printf "${BLUE}done\n${RESET}"

printf "${BLUE}Waiting for lightning to strike...\n${RESET}"
VBoxManage startvm "${NAME}"
printf "${YELLOW}KA-BOOM!\n${RESET}"

printf "\n\n"
printf "${GREEN}%s${RESET}\n" "${HR}"
printf "${GREEN}"
fold -s -w 72 <<< "Look! It's moving. It's alive. It's alive... It's alive, it's moving, it's alive, it's alive, it's alive, it's alive, IT'S ALIVE! "
printf "${RESET}"
printf "${GREEN}%s${RESET}\n" "${HR}"
printf "\n\n"
pak
