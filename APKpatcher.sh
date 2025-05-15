#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BLACK='\033[0;30m'
ORANGE='\033[0;33m'
PINK='\033[1;35m'
LIME='\033[1;32m'
TEAL='\033[0;36m'
VIOLET='\033[0;35m'
GOLD='\033[0;33m'
SILVER='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "   ___,  , __  ,     , __                _               "
    echo "  /   | /|/  \/|   //|/  \              | |              "
    echo " |    |  |___/ |__/  |___/ __, _|_  __  | |     _   ,_   "
    echo " |    |  |     | \   |    /  |  |  /    |/ \   |/  /  |  "
    echo "  \__/\_/|     |  \_/|    \_/|_/|_/\___/|   |_/|__/   |_/"
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}Author: alienkrishn${NC}"
    echo -e "${BLUE}A powerful tool for APK modification${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}\n"
}

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf "\r${YELLOW}[%c]${NC} Processing..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%-30s\r" " "
}

check_dependencies() {
    local missing=0
    declare -A tools=(
        ["apkeditor"]="APK manipulation"
        ["apksigner"]="APK signing"
        ["keytool"]="Keystore generation"
        ["jarsigner"]="Alternative signing"
        ["base64"]="Base64 encoding"
    )

    for tool in "${!tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${RED}[!]${NC} Missing: $tool (${tools[$tool]})"
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        echo -e "\n${RED}[!]${NC} ${BOLD}Error: Missing dependencies. Please install them.${NC}"
        exit 1
    fi
}

sign_apk() {
    local input_apk=$1
    local output_apk="${input_apk%.*}_signed.apk"
    local keystore="$PREFIX/apkpatcher/key/apkpatcher.keystore"
    local alias="apkpatcher"
    local password="apkpatcher"

    echo -e "${YELLOW}[*]${NC} ${BOLD}Generating/Checking Keystore${NC}"
    if [ ! -f "$keystore" ]; then
        (keytool -genkey -v -keystore "$keystore" -alias "$alias" -keyalg RSA -keysize 2048 -validity 10000 -storepass "$password" -keypass "$password" -dname "CN=apkpatcher, OU=apkpatcher, O=apkpatcher, L=Unknown, ST=Unknown, C=IN" > /dev/null 2>&1) &
        spinner
        echo -e "${GREEN}[+]${NC} Keystore generated"
    else
        echo -e "${GREEN}[+]${NC} Keystore found"
    fi

    echo -e "${YELLOW}[*]${NC} ${BOLD}Signing APK${NC}"
    if command -v apksigner >/dev/null 2>&1; then
        (apksigner sign --ks "$keystore" --ks-pass pass:"$password" --ks-key-alias "$alias" --key-pass pass:"$password" --out "$output_apk" "$input_apk" > /dev/null 2>&1) &
        spinner
        echo -e "${GREEN}[+]${NC} Signed with apksigner"
    else
        (jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore "$keystore" -storepass "$password" -keypass "$password" "$input_apk" "$alias" > /dev/null 2>&1) &
        spinner
        mv "$input_apk" "$output_apk"
        echo -e "${GREEN}[+]${NC} Signed with jarsigner"
    fi

    if [ ! -f "$output_apk" ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to sign APK${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Output: $output_apk"
}

merge_apk() {
    local input_apk=$1
    local output_apk=$2

    echo -e "${YELLOW}[*]${NC} ${BOLD}Merging APK${NC}"
    (apkeditor m -i "$input_apk" -o "$output_apk" > /dev/null 2>&1) &
    spinner

    if [ ! -f "$output_apk" ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to merge APK${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Merged APK created"
}

decompile_apk() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Decompiling APK${NC}"
    (apkeditor d -i "$TARGET_APK" -o target > /dev/null 2>&1) &
    spinner

    if [ ! -d "target" ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to decompile APK${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} APK decompiled"
}

find_launcher_activity() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Finding Launcher Activity${NC}"
    local manifest_file="target/AndroidManifest.xml"
    LAUNCHER_ACTIVITY=$(grep -A 20 "<activity" "$manifest_file" | grep -B 20 "android.intent.action.MAIN" | grep -B 20 "android.intent.category.LAUNCHER" | grep -m 1 "android:name" | cut -d '"' -f 2)

    if [ -z "$LAUNCHER_ACTIVITY" ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Could not find launcher activity${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Launcher activity: $LAUNCHER_ACTIVITY"

    SMALI_PATH=$(echo "$LAUNCHER_ACTIVITY" | sed 's/\./\//g')
    SMALI_FILE="target/smali/classes/$SMALI_PATH.smali"

    if [ ! -f "$SMALI_FILE" ]; then
        SMALI_FILE=$(find target/smali/classes -name "$(basename "$SMALI_PATH").smali" | head -1)
        if [ -z "$SMALI_FILE" ]; then
            echo -e "${RED}[!]${NC} ${BOLD}Error: Smali file not found${NC}"
            return 1
        fi
    fi
    echo -e "${GREEN}[+]${NC} Smali file: $SMALI_FILE"

    if ! grep -q ".method.*onCreate(Landroid/os/Bundle;)V" "$SMALI_FILE"; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: onCreate method not found${NC}"
        return 1
    fi
}

inject_standard_toast() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Injecting Standard Toast${NC}"
    TOAST_MSG_ESCAPED=$(echo "$TOAST_MSG" | sed 's/[\\"]/\\&/g')
    TOAST_CODE="    const\/4 v0, 0x1\n\n    const-string v1, \"$TOAST_MSG_ESCAPED\"\n\n    invoke-static {p0, v1, v0}, Landroid\/widget\/Toast;->makeText(Landroid\/content\/Context;Ljava\/lang\/CharSequence;I)Landroid\/widget\/Toast;\n\n    move-result-object v0\n\n    invoke-virtual {v0}, Landroid\/widget\/Toast;->show()V"

    sed -i "/\.method.*onCreate(Landroid\/os\/Bundle;)V/,/\.end method/ {
        /invoke-super.*onCreate.*/a \\
$TOAST_CODE
    }" "$SMALI_FILE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to inject toast${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Standard toast injected"
}

inject_colored_toast() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Injecting Colored Toast${NC}"
    
    echo -e "${PURPLE}${BOLD}Available Colors:${NC}"
    echo -e "${WHITE}1) White (#FFFFFF)${NC}"
    echo -e "${RED}2) Red (#FF0000)${NC}"
    echo -e "${BLUE}3) Blue (#0000FF)${NC}"
    echo -e "${YELLOW}4) Yellow (#FFEA00)${NC}"
    echo -e "${GREEN}5) Green (#00FF00)${NC}"
    echo -e "${BLACK}6) Black (#000000)${NC}"
    echo -e "${PINK}7) Pink (#FF19BE)${NC}"
    echo -e "${ORANGE}8) Orange (#FF8400)${NC}"
    echo -e "${LIME}9) Lime (#00FF00)${NC}"
    echo -e "${TEAL}10) Teal (#008080)${NC}"
    echo -e "${VIOLET}11) Violet (#EE82EE)${NC}"
    echo -e "${GOLD}12) Gold (#FFD700)${NC}"
    echo -e "${SILVER}13) Silver (#C0C0C0)${NC}"
    
    read -p "Select color [1-13]: " COLOR_CHOICE
    case $COLOR_CHOICE in
        1) COLOR_CODE="#FFFFFF" ;;
        2) COLOR_CODE="#FF0000" ;;
        3) COLOR_CODE="#0000FF" ;;
        4) COLOR_CODE="#FFEA00" ;;
        5) COLOR_CODE="#00FF00" ;;
        6) COLOR_CODE="#000000" ;;
        7) COLOR_CODE="#FF19BE" ;;
        8) COLOR_CODE="#FF8400" ;;
        9) COLOR_CODE="#00FF00" ;;
        10) COLOR_CODE="#008080" ;;
        11) COLOR_CODE="#EE82EE" ;;
        12) COLOR_CODE="#FFD700" ;;
        13) COLOR_CODE="#C0C0C0" ;;
        *) COLOR_CODE="#FFFFFF" ;;
    esac

    TOAST_MSG_ESCAPED=$(echo "$TOAST_MSG" | sed 's/[\\"]/\\&/g')
    TOAST_CODE="    const-string v0, \"<b><font color='$COLOR_CODE'>$TOAST_MSG_ESCAPED</font></b>\"\n\n    invoke-static {v0}, Landroid/text/Html;->fromHtml(Ljava/lang/String;)Landroid/text/Spanned;\n\n    move-result-object v0\n\n    const/4 v1, 0x1\n\n    invoke-static {p0, v0, v1}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;\n\n    move-result-object v2\n\n    invoke-virtual {v2}, Landroid/widget/Toast;->show()V"

    sed -i "/\.method.*onCreate(Landroid\/os\/Bundle;)V/,/\.end method/ {
        /invoke-super.*onCreate.*/a \\
$TOAST_CODE
    }" "$SMALI_FILE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to inject colored toast${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Colored toast injected (Color: $COLOR_CODE)"
}

inject_base64_toast() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Injecting Base64 Toast${NC}"
    BASE64_MSG=$(echo -n "$TOAST_MSG" | base64)
    BASE64_MSG_ESCAPED=$(echo "$BASE64_MSG" | sed 's/[\\"]/\\&/g')
    
    TOAST_CODE="    const-string v1, \"$BASE64_MSG_ESCAPED\"\n\n    const/4 v0, 0x0\n\n    invoke-static {v1, v0}, Landroid/util/Base64;->decode(Ljava/lang/String;I)[B\n\n    move-result-object v0\n\n    new-instance v1, Ljava/lang/String;\n\n    invoke-direct {v1, v0}, Ljava/lang/String;-><init>([B)V\n\n    const/4 v0, 0x1\n\n    invoke-static {p0, v1, v0}, Landroid/widget/Toast;->makeText(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;\n\n    move-result-object v0\n\n    invoke-virtual {v0}, Landroid/widget/Toast;->show()V"

    sed -i "/\.method.*onCreate(Landroid\/os\/Bundle;)V/,/\.end method/ {
        /invoke-super.*onCreate.*/a \\
$TOAST_CODE
    }" "$SMALI_FILE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to inject base64 toast${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Base64 toast injected"
    echo -e "${GREEN}[+]${NC} Original message: $TOAST_MSG"
    echo -e "${GREEN}[+]${NC} Base64 encoded: $BASE64_MSG"
}

inject_dialog() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Injecting Custom Dialog${NC}"
    
    read -p "Enter dialog title: " DIALOG_TITLE
    read -p "Enter dialog message: " DIALOG_MSG
    read -p "Enter positive button text: " POSITIVE_BTN
    
    TITLE_ESCAPED=$(echo "$DIALOG_TITLE" | sed 's/[\\"]/\\&/g')
    MSG_ESCAPED=$(echo "$DIALOG_MSG" | sed 's/[\\"]/\\&/g')
    BTN_ESCAPED=$(echo "$POSITIVE_BTN" | sed 's/[\\"]/\\&/g')
    
    DIALOG_CODE="    new-instance v0, Landroid\/app\/AlertDialog\$Builder;\n\n    invoke-direct {v0, p0}, Landroid\/app\/AlertDialog\$Builder;-><init>(Landroid\/content\/Context;)V\n\n    const-string v1, \"$TITLE_ESCAPED\"\n\n    invoke-virtual {v0, v1}, Landroid\/app\/AlertDialog\$Builder;->setTitle(Ljava\/lang\/CharSequence;)Landroid\/app\/AlertDialog\$Builder;\n\n    move-result-object v0\n\n    const-string v1, \"$MSG_ESCAPED\"\n\n    invoke-virtual {v0, v1}, Landroid\/app\/AlertDialog\$Builder;->setMessage(Ljava\/lang\/CharSequence;)Landroid\/app\/AlertDialog\$Builder;\n\n    move-result-object v0\n\n    const-string v1, \"$BTN_ESCAPED\"\n\n    const\/4 v2, 0x0\n\n    invoke-virtual {v0, v1, v2}, Landroid\/app\/AlertDialog\$Builder;->setPositiveButton(Ljava\/lang\/CharSequence;Landroid\/content\/DialogInterface\$OnClickListener;)Landroid\/app\/AlertDialog\$Builder;\n\n    move-result-object v0\n\n    invoke-virtual {v0}, Landroid\/app\/AlertDialog\$Builder;->show()Landroid\/app\/AlertDialog;"

    sed -i "/\.method.*onCreate(Landroid\/os\/Bundle;)V/,/\.end method/ {
        /invoke-super.*onCreate.*/a \\
$DIALOG_CODE
    }" "$SMALI_FILE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to inject dialog${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Custom dialog injected with:"
    echo -e "${GREEN}[+]${NC} Title: $DIALOG_TITLE"
    echo -e "${GREEN}[+]${NC} Message: $DIALOG_MSG"
    echo -e "${GREEN}[+]${NC} Button: $POSITIVE_BTN"
}

bypass_signature() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Bypassing Signature Checks${NC}"
    
    find "target/smali" -type f -name "*.smali" | while read -r smali_file; do
        sed -i \
            -e 's/^\(\s*\)invoke-virtual\(\s\{1,\}\).*Landroid\/content\/pm\/PackageManager;->checkSignatures.*/&\n\1const\/4 v0, 0x0/g' \
            -e 's/^\(\s*\)invoke-virtual\(\s\{1,\}\).*Landroid\/content\/pm\/PackageManager;->getPackageInfo.*/&\n\1const\/4 v0, 0x1/g' \
            -e 's/^\(\s*\)invoke-static\(\s\{1,\}\).*Landroid\/content\/pm\/Signature;->equals.*/&\n\1const\/4 v0, 0x1/g' \
            "$smali_file"
        
        sed -i \
            -e 's/^\(\.method.*checkSignature.*Z\)/\1\n    const\/4 v0, 0x1\n    return v0/g' \
            -e 's/^\(\.method.*verifySignature.*Z\)/\1\n    const\/4 v0, 0x1\n    return v0/g' \
            -e 's/^\(\.method.*isValidSignature.*Z\)/\1\n    const\/4 v0, 0x1\n    return v0/g' \
            -e 's/^\(\.method.*validateSignature.*Z\)/\1\n    const\/4 v0, 0x1\n    return v0/g' \
            "$smali_file"
    done

    find "target/smali" -type f -name "LicenseClient*.smali" -exec sed -i \
        -e 's/^\(\.method.*verifyLicense.*\)/\1\n    const\/16 v0, 0x0\n    invoke-virtual {p0, v0}, LicenseClientV3;->handleValidLicense(I)V\n    return-void/g' \
        {} +

    echo -e "${GREEN}[+]${NC} Signature checks bypassed"
}

rebuild_apk() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Rebuilding APK${NC}"
    (apkeditor b -i target -o "$OUTPUT_APK" > /dev/null 2>&1) &
    spinner

    if [ ! -f "$OUTPUT_APK" ]; then
        echo -e "${RED}[!]${NC} ${BOLD}Error: Failed to rebuild APK${NC}"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} APK rebuilt"
}

cleanup() {
    echo -e "${YELLOW}[*]${NC} ${BOLD}Cleaning Up${NC}"
    rm -rf target "$OUTPUT_APK" "${OUTPUT_APK%.*}_signed.apk.idsig" 2>/dev/null
    echo -e "${GREEN}[+]${NC} Temporary files removed"
}

main() {
    while true; do
        show_banner
        check_dependencies

        echo -e "${CYAN}${BOLD}Select Operation${NC}"
        echo -e "${CYAN}════════════════${NC}"
        echo -e "${BLUE}1) Sign APK${NC}"
        echo -e "${BLUE}2) Merge APK (APKs, APKM)${NC}"
        echo -e "${BLUE}3) Bypass Signature Checks${NC}"
        echo -e "${BLUE}4) Inject Toast Message${NC}"
        echo -e "${BLUE}5) Inject Custom Dialog${NC}"
        echo -e "${RED}6) Exit${NC}"
        echo -e "${CYAN}════════════════${NC}"
        read -p "Enter choice [1-6]: " CHOICE
        echo

        case $CHOICE in
            1)
                echo -e "${CYAN}${BOLD}Sign APK${NC}"
                echo -e "${CYAN}────────${NC}"
                read -p "Enter APK path: " TARGET_APK
                if [ ! -f "$TARGET_APK" ]; then
                    echo -e "${RED}[!]${NC} ${BOLD}Error: File not found${NC}"
                    continue
                fi
                sign_apk "$TARGET_APK"
                ;;
            2)
                echo -e "${CYAN}${BOLD}Merge APK${NC}"
                echo -e "${CYAN}─────────${NC}"
                read -p "Enter APK/APKs/APKM path: " TARGET_APK
                if [ ! -f "$TARGET_APK" ]; then
                    echo -e "${RED}[!]${NC} ${BOLD}Error: File not found${NC}"
                    continue
                fi
                read -p "Enter output APK name (no .apk): " OUTPUT_BASE
                OUTPUT_APK="${OUTPUT_BASE}.apk"
                merge_apk "$TARGET_APK" "$OUTPUT_APK"
                sign_apk "$OUTPUT_APK"
                ;;
            3)
                echo -e "${CYAN}${BOLD}Bypass Signature Checks${NC}"
                echo -e "${CYAN}───────────────────────${NC}"
                read -p "1. Enter target APK path: " TARGET_APK
                if [ ! -f "$TARGET_APK" ]; then
                    echo -e "${RED}[!]${NC} ${BOLD}Error: File not found${NC}"
                    continue
                fi
                read -p "2. Enter output APK name (no .apk): " OUTPUT_BASE
                OUTPUT_APK="${OUTPUT_BASE}.apk"
                decompile_apk || continue
                bypass_signature
                rebuild_apk || continue
                sign_apk "$OUTPUT_APK"
                cleanup
                ;;
            4)
                echo -e "${CYAN}${BOLD}Inject Toast Message${NC}"
                echo -e "${CYAN}─────────────────────${NC}"
                read -p "1. Enter toast message: " TOAST_MSG
                if [ -z "$TOAST_MSG" ]; then
                    echo -e "${RED}[!]${NC} ${BOLD}Error: Toast message cannot be empty${NC}"
                    continue
                fi
                read -p "2. Enter target APK path: " TARGET_APK
                if [ ! -f "$TARGET_APK" ]; then
                    echo -e "${RED}[!]${NC} ${BOLD}Error: File not found${NC}"
                    continue
                fi
                read -p "3. Enter output APK name (no .apk): " OUTPUT_BASE
                OUTPUT_APK="${OUTPUT_BASE}.apk"
                
                echo -e "${PURPLE}${BOLD}Select Toast Type:${NC}"
                echo -e "1) Standard Toast"
                echo -e "2) Colored Toast"
                echo -e "3) Base64 Encoded Toast"
                read -p "Enter choice [1-3]: " TOAST_TYPE
                
                decompile_apk || continue
                find_launcher_activity || continue
                
                case $TOAST_TYPE in
                    1) inject_standard_toast ;;
                    2) inject_colored_toast ;;
                    3) inject_base64_toast ;;
                    *) inject_standard_toast ;;
                esac || continue
                
                rebuild_apk || continue
                sign_apk "$OUTPUT_APK"
                cleanup
                ;;
            5)
                echo -e "${CYAN}${BOLD}Inject Custom Dialog${NC}"
                echo -e "${CYAN}─────────────────────${NC}"
                read -p "1. Enter target APK path: " TARGET_APK
                if [ ! -f "$TARGET_APK" ]; then
                    echo -e "${RED}[!]${NC} ${BOLD}Error: File not found${NC}"
                    continue
                fi
                read -p "2. Enter output APK name (no .apk): " OUTPUT_BASE
                OUTPUT_APK="${OUTPUT_BASE}.apk"
                
                decompile_apk || continue
                find_launcher_activity || continue
                inject_dialog
                rebuild_apk || continue
                sign_apk "$OUTPUT_APK"
                cleanup
                ;;
            6)
                echo -e "${YELLOW}[*]${NC} ${BOLD}Thanks for using this tool!${NC}"
                sleep 1
                exit 0
                ;;
            *)
                echo -e "${RED}[!]${NC} ${BOLD}Error: Invalid choice${NC}"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

main
