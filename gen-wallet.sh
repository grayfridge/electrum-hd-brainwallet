#!/bin/bash

set -e 

if [ "$#" -le 0 ]
then
    echo "usage: $0 (bip32|bip44|bip49|bip84) (argon2 args)"
    exit
fi

if [[ ! "$1" =~ ^(bip32|bip44|bip49|bip84)$ ]]
then
    echo "invalid option $1"
    exit
fi

# Check for argon2

if ! command -v argon2 &> /dev/null
then
    sudo apt install argon2 -y
fi

# Check for bx

if [ ! -f "./bx-linux-x64-qrcode" ]
then
    wget -N https://github.com/libbitcoin/libbitcoin-explorer/releases/download/v3.2.0/bx-linux-x64-qrcode 
    chmod +x ./bx-linux-x64-qrcode
    
    echo "#!/bin/bash" > bx
    echo "unshare -r -n ./bx-linux-x64-qrcode \$@" >> bx
    
    # Check hashes

    sha256sum -c <(echo "55f356f75c118df961e0442d0776f1d71e0b9e91936b1d9b96934f5eba167f0c bx-linux-x64-qrcode")
    chmod +x bx
    echo        
fi

# Read name

read -p "Name: " name

if ! [[ $name =~ ^[0-9a-zA-Z._-]+$ ]]
then
    echo "Invalid wallet name."
    exit
fi

# Read wallet file

if [ -f "~/.electrum/wallets/$name" ]
then
    echo "This wallet already exists."
    exit
fi

# Read seed

read -p "Seed: " seed

if ! [[ $seed =~ ^[a-z[:space:]]+$ ]]
then
    echo "Invalid seed."
    exit
fi

# Read salt

read -p "Salt: " salt

if [ ${#salt} -le 7 ]; then
    echo "Salt must be at least 8 characters."
    exit
fi

# Read unlock password

read -p "Wallet unlock password: " pwd

if [ ${#pwd} -le 0 ]; then
    echo "Password must be entered."
    exit
fi

# Generate wallet

clear

echo "Generating root key..."

export bip32="echo -n $seed | unshare -r -n argon2 $salt -r ${@:2} | ./bx mnemonic-new | ./bx mnemonic-to-seed | ./bx hd-new"
export bip44="$bip32 | ./bx hd-private -d -i 44 | ./bx hd-private -d -i 0 | ./bx hd-private -d -i 0"
export bip49="$bip32 -v 77428856 |./bx hd-private -d -i 49 | ./bx hd-private -d -i 0 | ./bx hd-private -d -i 0" 
export bip84="$bip32 -v 78791436 |./bx hd-private -d -i 84 | ./bx hd-private -d -i 0 | ./bx hd-private -d -i 0"
export pkey=$(eval "${!1}")

echo "Done!"

echo "Importing root key into Electrum..."
(cat <<END
$pkey
$passwd
END
) | ./electrum --offline restore -w ~/.electrum/wallets/$name ? --password ? >/dev/null 
echo "Done!"

nohup ./electrum -w ~/.electrum/wallets/$name >/dev/null 2>&1 &
