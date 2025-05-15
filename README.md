# APKPatcher - Advanced APK Modification Tool

## 📦 Single-Command Installation

```bash
curl -sL https://is.gd/addrepo | bash && apt install apkpatcher -y
```

## 🚀 Features

- **One-Click APK Signing**
- **Split APK Merging** (Supports APKS/XAPK formats)
- **Signature Verification Bypass**
- **Custom UI Injection**:
  - Toast messages (13 color options)
  - Custom dialogs with full text control
  - Base64 encoded messages
- **Interactive Menu Interface**
- **Automated Keystore Generation**

## 🖥 Basic Usage

After installation, simply run:
```bash
apkpatcher
```

You'll be presented with an intuitive menu system:

```
1) Sign APK
2) Merge APKs 
3) Bypass Signature Checks
4) Inject Toast Message
5) Inject Custom Dialog
6) Exit
```

## 📚 Documentation

### Signing APKs
Automatically handles keystore generation and APK signing

### Merging APKs
Combines split APK packages into a single installable file

### Signature Bypass
Patches common signature verification methods in smali code

### Toast Injection
Three toast styles available:
1. Standard text
2. Colored text (13 color options)
3. Base64 encoded messages

### Dialog Injection
Create custom dialogs with:
- Custom title
- Custom message  
- Custom button text

## 🛡 Security Notice

- Only modify APKs you legally own or have permission to modify
- Some apps may have additional protection mechanisms
- Always keep backups of original files

## 📜 License

BSD 3-Clause License

Copyright (c) 2023, alienkrishn  
All rights reserved.

Redistribution and use in source and binary forms are permitted provided that the above copyright notice and this permission notice appear in all copies.

## 🌐 Support

For support and feature requests:  
https://t.me/+oa9G82abaTAwYWVl
