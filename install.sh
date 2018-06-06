#!/bin/sh

WORKINGDIR=/tmp/pamm

# OSTYPE maybe not be defined for /bin/sh
if [ -z $OSTYPE ]; then
    OSTYPE=$(uname | tr [:upper:] [:lower:])
fi

case $OSTYPE in
    linux*)
        PLATFORM="linux"
        [ -z "${XDG_DATA_HOME}" ] && XDG_DATA_HOME="${HOME}/.local/share"
        PAMMDIR="${XDG_DATA_HOME}/pamm"
        APPDIR="$PAMMDIR/resources/app"
        ;;
    darwin*)
        PLATFORM="darwin"
        # PAMMDIR="$HOME/Library/Application Support/Uber Entertainment/Planetary Annihilation/pamm"
        PAMMDIR="$HOME/Desktop/pamm"
        APPDIR="$PAMMDIR/Electron.app/Contents/Resources/app"
        ;;
    *)
        echo Unsupported platform: $OSTYPE
        exit 1
        ;;
esac

wget --version >/dev/null 2>&1 && HTTPCLIENT="wget"
curl --version >/dev/null 2>&1 && HTTPCLIENT="curl"
if [ -z $HTTPCLIENT ]; then
    echo "wget or curl not found!"
    exit 1
fi

mkdir $WORKINGDIR

echo "Downloading latest PAMM release..."

LATEST_PAMM_URL="https://github.com/flubbateios/pamm-atom/archive/master.zip"
PAMM_ARCHIVE="$WORKINGDIR/stable.zip"

if [ $HTTPCLIENT = "wget" ]; then
    wget "$LATEST_PAMM_URL" -O "$PAMM_ARCHIVE"
else
    curl -L "$LATEST_PAMM_URL" -o "$PAMM_ARCHIVE"
fi

if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

echo "Find latest Electron release..."

LATEST_ATOM_URL="https://github.com/electron/electron/releases/latest"

if [ $HTTPCLIENT = "wget" ]; then
    HTML=`wget -qO- $LATEST_ATOM_URL`
else
    HTML=`curl -L $LATEST_ATOM_URL`
fi

if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

ATOM_ARCHIVE_URL=`echo $HTML | egrep -o "/electron/electron/releases/download/v[^\"]*/electron-v[^\"]*-$PLATFORM-x64.zip" | head -1`

if [ -z $ATOM_ARCHIVE_URL ]; then
    echo "Unable to extract link to electron from GitHub release"
    exit 1
fi

ATOM_ARCHIVE_URL="https://github.com$ATOM_ARCHIVE_URL"


ATOM_ARCHIVE=`echo $ATOM_ARCHIVE_URL | sed -E 's/.+\/(.+)/\1/'`
ATOM_ARCHIVE="$WORKINGDIR/$ATOM_ARCHIVE"

rm -rf "$PAMMDIR"
mkdir -p "$PAMMDIR"

echo "Downloading Electron..."
echo "  from: $ATOM_ARCHIVE_URL"
echo "  to: $ATOM_ARCHIVE"

if [ $HTTPCLIENT = "wget" ]; then
    wget "$ATOM_ARCHIVE_URL" -O "$ATOM_ARCHIVE"
else
    curl -L "$ATOM_ARCHIVE_URL" -o "$ATOM_ARCHIVE"
fi

if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

echo "Extracting Electron..."
unzip -q -u "$ATOM_ARCHIVE" -d "$PAMMDIR"
if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

echo "Extracting PAMM module..."
unzip -q -u "$PAMM_ARCHIVE" -d "$WORKINGDIR"
if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

echo "Copying PAMM module..."
cp -R "$WORKINGDIR/pamm-atom-master/app" "$APPDIR"
if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

echo "Extracting node_modules..."
mkdir "$APPDIR/node_modules"
unzip -q -u "$WORKINGDIR/pamm-atom-master/node_modules.zip" -d "$APPDIR/node_modules"
if [ $? -gt 0 ]; then
    echo "ERROR!"
    exit 1
fi

echo "Cleaning up tmp files..."
rm -rf "$WORKINGDIR"

echo "Installed in $APPDIR"

case $PLATFORM in
    linux)
        mv "$PAMMDIR/electron" "$PAMMDIR/pamm"

        # try to create desktop shortcut & protocol handler
        cat > ${XDG_DATA_HOME}/applications/pamm.desktop <<-EOL
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=PAMM
        Comment=PA Mod Manager
        Exec=$PAMMDIR/pamm "%u"
        Icon=$PAMMDIR/resources/app/assets/img/pamm.png
        MimeType=x-scheme-handler/pamm;
EOL

        # update-desktop-database does not exist anymore, but keep it for distros that still use it
        which update-desktop-database > /dev/null
        if [ $? -eq 0 ]; then
            update-desktop-database ${XDG_DATA_HOME}/applications
        fi

        echo "PAMM has been successfully installed."
        echo "  => $PAMMDIR"
        $PAMMDIR/pamm
        ;;
    darwin)
        mv "$PAMMDIR/Electron.app" "$PAMMDIR/PAMM.app"
        open "$PAMMDIR/PAMM.app"
        echo "PAMM has been successfully installed."
        ;;
esac
