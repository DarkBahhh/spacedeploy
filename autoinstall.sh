#!/bin/bash
## Install GNU/Emacs from source && deploy Spacemacs distrib with user configuration.
##
## Tested with 'Debian10'/'Debian11', 'Emacs29.0.50', 'Spacemacs0.999.0'.




###############################################################################
#                                  Variables                                  #
###############################################################################

# Requirements vars: ##########################################################
#  - REQUIRE: Packages required for installation and deployment               #
#       value -> need a string with packages names separated by whitespace    #
#  - SUCMD: Command to use for elevated privileges                            #
#       value -> "sudo" to use sudo command                                   #
#       value -> "su" to use su command                                       #
###############################################################################
REQUIRE="git build-essential automake texinfo libncurses5-dev libacl1-dev \
libtiff5-dev libgif-dev libpng-dev libxpm-dev libgtk-3-dev libgnutls28-dev \
libmagickwand-dev libjpeg-dev libxaw7 libxaw7-dev"
SUCMD="su"

# Emacs install vars: #########################################################
#  - SRC_DIR: Path where emacs source will be stored (or is stored)           #
#       value -> If the value is "TEMP", source will be stored in '/tmp'      #
#  - GET_EMACS: Method to get emacs source                                    #
#       value -> "git" to get source from a git repository (need "EMACS_GIT") #
#       value -> "zip" to get source from a local zip file (need "EMACS_ZIP") #
#       value -> if unset, SRC_DIR var need to be a path to Emacs sources     #
#                directory named emacs (like this '<SRC_DIR>/emacs')        #
#       note: this var must be set to use the update|unbuild options (-u|-d)  #
#  - EMACS_GIT: URL to a git repository                                       #
#  - EMACS_ZIP: Path to a .zip file. This .zip file need to contain a source  #
#               directory with the same name as the zip file without extension#
#               or '.git' or '.d'. (value may also be the uncompressed dir)   #
#  - EMACS_BRANCH: Git branch to use (if unset default branch is use) OPTIONAL#
#  - INSTALL_DIR: Root directory for the emacs 'make install'                 #
#       value -> If the value is "GLOB", the "--prefix" flag won't be use     #
#       note: <INSTALL_DIR>/bin will be export to the $PATH environment var   #
#  - EMACS_SERVICE: File to use for setup emacs as an user service OPTIONAL   #
#       value -> If the value is "DEF", default file from source will be used #
#       value -> If unset emacs will not be integrate to systemd              #
#  - EMACS_INIT: File to use as Emacs 'init.el' file OPTIONAL                 #
#       value -> If value end with ".zip", it will be unzip as ".emacs.d"     #
#  - EMACS_ADDPKG: Folder with your emacs additional packages (will be stored #
#                  in '.emacs.d' directory) OPTIONAL                          #
###############################################################################
GET_EMACS="git"
EMACS_GIT="https://git.savannah.gnu.org/git/emacs.git"
EMACS_ZIP="emacs-29.0.50.zip"
SRC_DIR="$HOME/.local/src"
INSTALL_DIR="$HOME/.local"
# EMACS_SERVICE="custom_emacs.service"
# EMACS_INIT="myinit.el"
# EMACS_ADDPKG="emacs-additional-packages"

# Spacemacs deploy vars: ######################################################
#  - GET_SPACE: Method to get spacemacs sources                               #
#       value -> "git" to get sources from a git repository (need "SPACE_GIT")#
#       value -> "zip" to get sources from a local zip file (need "SPACE_ZIP")#
#  - SPACE_GIT: URL to a git repository                                       #
#  - SPACE_ZIP: Path to a zip file (the unzipped dir must be '.emacs.d')      #
#  - SPACE_BRANCH: Git branch to use (if unset default branch is use) OPTIONAL#
#  - SPACE_DOT: File to use as Spacemacs configuration ('~/.spacemacs' file)  #
#       value -> If unset it will be create at emacs start                    #
#       value -> If value end with ".zip", it will be unzip as ".spacemacs.d" #
#  - SPACE_EINIT: Custome emacs init file '~/.emacs.d/init.el'  OPTIONAL      #
#  - SPACE_REQ: Some system packages required for some emacs modes OPTIONAL #
#       value -> need a string with packages names separated with whitespace  #
###############################################################################
GET_SPACE="git"
SPACE_GIT="https://github.com/syl20bnr/spacemacs"
SPACE_ZIP="emacsdotd.zip"
SPACE_BRANCH="develop"
# SPACE_DOT="dotspacemacs"
# SPACE_EINIT="emacs-custom-init.el"
# SPACE_REQ="gnome-shell-extension-no-annoyance"




###############################################################################
#                                     Code                                    #
###############################################################################
DATE=$(date +%Y%m%d)
TEMP_DIR="/tmp/emacsinst-$DATE.tmp"

## Program usage
usage(){
    printf "Deploy Emacs + Spacemacs conf\n"
    printf "Format: `basename $0` [WORKDIR] [-e|-s|-u|-d|-r|-h|--service]\n"
    printf "\nArgument:\n"
    printf "\tWORKDIR: PATH to a workding directory (if empty, the local PATH is used)\n"
    printf "\nOptions:\n"
    printf "\t-e        -> Run only Emasc installation\n"
    printf "\t-s        -> Only deploy your Spacemacs config\n"
    printf "\t-u        -> Update Emacs source and rebuild\n"
    printf "\t-d        -> Unbuild Emacs but keep source\n"
    printf "\t-r        -> Unbuild Emacs and remove completely Emacs and Spacemacs ressources\n"
    printf "\t-h        -> Print this help output\n"
    printf "\t--service -> Setup emacs as a systemd service for the running user and exit\n"
    printf "\t             (emacs install had to be performed and this work only for non-root users)\n"
    printf "\nConfiguration:\n"
    printf "\tYou can find some configuration variables at the top of this script\n"
    printf "\nError code:\n"
    printf "\t1\t-> Error in command syntax\n"
    printf "\t2\t-> Error in configuration script part\n"
    printf "\t3\t-> Error source is mandatory for this option but don't exist\n"
    printf "\t4\t-> Error with usual command (mkdir, cp, mv, rm, export)\n"
    printf "\t5\t-> Error during su|sudo comamnd (for apt-get)\n"
    printf "\t6\t-> Error with automake (autogen.sh, configure, make)\n"
    printf "\t7\t-> Error with 'git' command\n"
    printf "\t8\t-> Error with 'unzip' command\n"
}

## Make tmp dir
mktmpdir(){
    mkdir -p $TEMP_DIR || error 4
}

## Deploy config method:
deployconfig(){
    # $1: PATH to the input file
    # $2: PATH to a file
    # $3: PATH to a directory
    case $1 in
        *".zip") unzip $1 -d $3 || error 8;;
        *) cp $1 $2 || error 4
    esac
}

## Install requirements:
instreq(){
    echo "Requirements installation:"
    if [[ $1 == "space" ]]; then
        packages="$SPACE_REQ"
    else
        packages="$REQUIRE"
    fi
    if [[ $SUCMD == "sudo" ]]; then
        sudo apt-get install -y $packages || error 5
    elif [[ $SUCMD == "su" ]]; then
        su -c "apt-get install -y $packages" || error 5
    else
        printf "AutoInstallError: Variable 'SUCMD' only take as value: 'sudo' or 'su'\n"
        error 2
    fi
}

## Emacs source:
getsrc(){
    echo "Getting Emacs source..."
    if [[ -z $GET_EMACS ]]; then
        if [[ ! -d "$scr_dir/emacs" ]]; then
            printf "AutoInstallError: '$SRC_DIR/emacs' does not exist!\n"
            error 3
        fi
        return
    fi
    if [[ $SRC_DIR == "TEMP" ]]; then
        mktmpdir
        SRC_DIR="$TEMP_DIR/emacs_sources"
    fi
    if [[ ! -d $SRC_DIR ]]; then
        mkdir -p $SRC_DIR || error 4
    fi
    if [ $GET_EMACS == 'git' ]; then
        git clone $EMACS_GIT $SRC_DIR'/emacs' || error 7
    elif [ $GET_EMACS == 'zip' ]; then
        if [[ -d $EMACS_ZIP ]]; then
            cp -r $EMACS_ZIP $SRC_DIR/emacs || error 4
            return
        fi
        unzip $EMACS_ZIP -d $SRC_DIR || error 8
        filename="${EMACS_ZIP%.*}"
        if [[ -d "$SRC_DIR/$filename.git" ]]; then
            ln -s $SRC_DIR/$filename.git $SRC_DIR/emacs || error 4
        elif [[ -d "$SRC_DIR/$filename" ]]; then
            ln -s $SRC_DIR/$filename $SRC_DIR/emacs || error 4
        elif [[ -d "$SRC_DIR/$filename.d" ]]; then
            ln -s $SRC_DIR/$filename.d $SRC_DIR/emacs || error 4
        else
            printf "AutoInstallError: Unzipped sources directory is not found\n"
            printf "\tIf you know witch path to use for sources directory, configure\n"
            printf "\t'EMACS_ZIP' variable with this path and restart $0 \n"
            exit 2
        fi
    else
        printf "AutoInstallError: Variable 'GET_EMACS' only take as value: 'git' or 'zip'\n"
        error 2
    fi
}

## Emacs user additinal packages
userpkg(){
    [[ ! -d ~/.emacs.d ]] && mkdir ~/.emacs.d
    case $EMACS_ADDPKG in
        *".zip") unzip $EMACS_ADDPKG -d ~/.emacs.d || error 4;;
        *) cp -rf $EMACS_ADDPKG ~/.emacs.d/ || error 4;;
    esac
}

## Setup Emacs in systemd for user
service_setup(){
    if [[ ! -d $HOME/.config/systemd/user/ ]]; then
        mkdir -p $HOME/.config/systemd/user/ || error 4
    fi
    if [[ -f $EMACS_SERVICE ]]; then
        cp $EMACS_SERVICE ~/.config/systemd/user/emacs.service || error 4
    elif [[ $EMACS_SERVICE == "DEF" ]]; then
        cp $INSTALL_DIR/lib/systemd/user/emacs.service ~/.config/systemd/user/emacs.service || error 4
    else
        printf "AutoInstallError: Variable 'EMACS_SERVICE' only take as value: 'DEF' or an existing file\n"
        error 2
    fi
    systemctl --user daemon-reload || error 4
    systemctl --user enable emacs.service || error 4
}

## Emacs build:
build(){
    echo "Configure & Make Emacs source..."
    # Change branch:
    if [[ ! -z $EMACS_BRANCH ]]; then
        cd $SRC_DIR'/emacs'
        git checkout $EMACS_BRANCH || error 7
        cd -
    fi

    # Ensure install dir:
    if [[ ! -d $INSTALL_DIR ]]; then
        mkdir -p $INSTALL_DIR || error 4
    fi

    # Configure prefix:
    if [[ ! $INSTALL_DIR == "GLOB" ]]; then
        prefix="--prefix=$INSTALL_DIR"
    fi

    # Make:
    cd $SRC_DIR'/emacs'
    ./autogen.sh || error 6
    ./configure --without-ns --without-dbus --with-gnutls --with-imagemagick --with-rsvg \
                --with-mailutils --with-xml2 --with-modules --without-compress-install \
                --with-x-toolkit=lucid $prefix || error 6
    make || error 6
    echo "Make Install Emacs source:"
    make install || error 6
    cd -

    # Add user local path:
    if [[ ! "$PATH" =~ "$INSTALL_DIR/bin" || ! $INSTALL_DIR == "GLOB" ]]; then
        export PATH="$PATH:$INSTALL_DIR/bin" || error 4
        echo -e "\nexport PATH=\"\$PATH:$INSTALL_DIR/bin\"\n" >> $HOME/.bashrc || error 4
    fi

    # Deploy emacs config
    if [[ ! -z $EMACS_INIT ]]; then
        [[ ! -d ~/.emacs.d && ! $EMACS_INIT == *".zip" ]] && mkdir ~/.emacs.d
        deployconfig $EMACS_INIT ~/.emacs.d/init.el $HOME
    fi

    # Deploy additionnal packages
    if [[ ! -z $EMACS_ADDPKG ]]; then
    userpkg
    fi

    # Setup emacs daemon in systemd (only for users)
    if [[ ! -z $EMACS_SERVICE && ! `whoami` == "root" ]]; then
        service_setup
    fi
}

## Emacs unbuild:
unbuild(){
    echo "Make Uninstall Emacs source:"
    if [[ ! -d "$SRC_DIR/emacs" ]] && [[ ! -L "$SRC_DIR/emacs" ]]; then
        printf "AutoInstallError: Can't unbuild emacs cause '$SRC_DIR/emacs' does not exist!\n"
        error 3
    fi
    cd $SRC_DIR'/emacs'
    make uninstall || error 6
    cd -
    if [[ ! -z $EMACS_SERVICE ]] && [[ -f $EMACS_SERVICE ]]; then
        rm ~/.config/systemd/user/emacs.service
    fi
}

## Deploy spacemacs:
spacedeploy(){
    echo "Deploying your Spacemacs config..."
    # Remove old emacs folder
    if [[ -d ~/.emacs.d ]]; then
        rm -rf ~/.emacs.d || error 4
    fi

    # Get:
    if [ $GET_SPACE == 'git' ]; then
        git clone $SPACE_GIT $HOME'/.emacs.d' || error 7
    elif [ $GET_SPACE == 'zip' ]; then
        unzip $SPACE_ZIP -d $HOME || error 8
    else
        printf "AutoInstallError: Variable 'GET_SPACE' only take as value: 'git' or 'zip'\n"
        error 2
    fi

    # Change branch:
    if [[ ! -z $SPACE_BRANCH ]]; then
        cd $HOME'/.emacs.d'
        git checkout $SPACE_BRANCH || error 7
        cd -
    fi

    # Configure Spacemacs:
    deployconfig $SPACE_DOT "$HOME/.spacemacs" "$HOME/.spacemacs.d"

    if [[ ! -z $SPACE_EINIT ]]; then
        deployconfig $SPACE_EINIT "$HOME/.emacs.d/init.el"
    fi

    # Deploy additionnal packages
    if [[ ! -z $EMACS_ADDPKG ]]; then
    userpkg
    fi

    # Install system package needed with spacemacs:
    if [ ! -z "$SPACE_REQ" ]; then
        instreq "space"
    fi
}

## Update Emacs:
updatemacs(){
    echo "Unbuild emacs from source..."

    # Unbuild old emacs
    unbuild

    # Update source
    if [ $GET_EMACS == 'git' ]; then
        cd $SRC_DIR'/emacs'
        git rebase || error 7
        cd -
    elif [ $GET_EMACS == 'zip' ]; then
        if [[ -L $SRC_DIR/emacs ]]; then
            rm $SRC_DIR/emacs
        elif [[ -d $SRC_DIR/emacs ]]; then
            mv $SRC_DIR/emacs $SRC_DIR/emacs-$DATE.old
        fi
        if [[ -d $EMACS_ZIP ]]; then
            cp -r $EMACS_ZIP $SRC_DIR/emacs || error 4
            return
        fi
        unzip $EMACS_ZIP -d $SRC_DIR || error 8
        filename="${EMACS_ZIP%.*}"
        if [[ -d "$SRC_DIR/$filename.git" ]]; then
            ln -s $SRC_DIR/$filename.git $SRC_DIR/emacs || error 4
        elif [[ -d "$SRC_DIR/$filename" ]]; then
            ln -s $SRC_DIR/$filename $SRC_DIR/emacs || error 4
        elif [[ -d "$SRC_DIR/$filename.d" ]]; then
            ln -s $SRC_DIR/$filename.d $SRC_DIR/emacs || error 4
        else
            printf "AutoInstallError: Unzipped sources directory is not found\n"
            printf "\tIf you konw witch path to use for sources directory, configure\n"
            printf "\t'EMACS_ZIP' variable with this path and restart $0 \n"
            exit 2
        fi
    else
        printf "AutoInstallError: Variable 'GET_EMACS' need to be set to use the update option (-u)\n"
        error 2
    fi

    # Build new emacs
    build
    cd -
}

## Remove Emacs and Spacemacs:
removeall(){
    unbuild
    rm "$SRC_DIR/emacs"
    rm -rf "$HOME/.emacs.d"
    rm -rf "$HOME/.spacemacs"
    rm -rf "$HOME/.spacemacs.d"
}

## Error message
error(){
    printf "AutoInstallError: Check this output and '-h' option for this error code: $1\n"
    if [[ -d $TEMP_DIR ]]; then
        printf "\t'$TEMP_DIR' was not removed.\n"
    fi
    exit $1
}



## Main code:

# Workdir:
[[ -d $1 ]] && cd $1 && shift

# Add zip to REQUIRE for 'zip' get source methode
[[ $GET_EMACS == 'zip' || $GET_SPACE == 'zip' ]] && REQUIRE="$REQUIRE zip"

# Run:
case $1 in
    -h|"help") usage; exit 0;;
    -u) updatemacs ; printf "Update done.\n" ; printf "Rebuild old src if something goes wrong,\n";
        if [[ $get_macs == 'git' ]]; then printf "\tUse git to find old emacs source.\n";
        elif [[ $GET_EMACS == 'zip' ]]; then printf "\tFind old emacs source in '$SRC_DIR'.\n";
        fi;;
    -d) unbuild ; printf "Emacs unbuild done.\n" ; printf "\tFind emacs source in '$SRC_DIR/emacs'.\n";;
    -e) instreq ; getsrc ; build ; printf "Emacs installation done.\n";
        printf "\tUse 'cd $SRC_DIR/emacs && make uninstall' if something goes wrong.\n";;
    -s) instreq ; spacedeploy ; printf "Spacemacs distribution has been deployed.\n";;
    -r) removeall ; printf "Emacs and Spacemacs files was removed.\n";;
    --service) [[ -z $EMACS_SERVICE ]] && printf "AutoInstallError: Variable 'EMACS_SERVICE need to be set for this option!\n" && exit 2;
               [[ ! -f $INSTALL_DIR ]] && printf "AutoInstallError: Variable 'INSTALL_DIR' must be set with an existing directory for this option!\n" && exit 2;
               [[ `whoami` == 'root' ]] && printf "AutoInstallError: Unable to setup emacs in system with root user!\n" && exit 2;
               service_setup; printf "Emacs service enabled for user '`whoami`'.";;
    "") instreq ; getsrc ; build ; spacedeploy ; printf "Deployment done.\n";
        printf "\tUse 'cd $SRC_DIR/emacs && make uninstall' if something goes wrong.\n";;
    *)  printf "AutoInstallError: '$1' need to be a exiting directory or an option!\nSee help output:\n";
        usage; exit 1;;
esac

# Delete temp dir
if [[ -d $TEMP_DIR ]]; then rm -rf $TEMP_DIR || exit 4; fi

# Chao a+
printf "Autoinstalled.\n"
