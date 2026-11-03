#!/bin/bash
# Identifiants des attributs et du thème Android utilisés par le manifeste (depuis android.jar).
J=~/wc14/apk/android.jar
javap -classpath $J -constants 'android.R$attr' | grep -E ' (drawable|icon|name|label|theme|exported|launchMode|screenOrientation|configChanges|process|debuggable|hardwareAccelerated|extractNativeLibs|minSdkVersion|targetSdkVersion|versionCode|versionName|glEsVersion|required|preferMinimalPostProcessing) ='
javap -classpath $J -constants 'android.R$style' | grep -E 'Theme_NoTitleBar_Fullscreen ='
