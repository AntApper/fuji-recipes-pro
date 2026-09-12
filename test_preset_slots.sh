#!/bin/bash

# Test script for libgphoto2 preset slot implementation
# Usage: ./test_preset_slots.sh [command] [args...]\n\n# Examples:
#   ./test_preset_slots.sh list
#   ./test_preset_slots.sh read 1
#   ./test_preset_slots.sh write 1 \"My Preset\" 1 3 2
#   ./test_preset_slots.sh clear

set -e

HELPER=\"FujiPTPClient/.build/debug/FujiPTPHelper\"

if [ ! -f \"$HELPER\" ]; then
    echo \"❌ FujiPTPHelper not found. Building...\"
    cd FujiPTPClient
    swift build -c debug
    cd ..
fi

function send_command() {
    local id=$1
    local cmd=$2
    local params=$3
    
    local json=\"{\\\"id\\\":\\\"$id\\\",\\\"command\\\":{\\\"$cmd\\\":$params}}\"
    echo \"📤 Sending: $json\" >&2
    echo \"$json\" | \"$HELPER\"
}

function test_connect() {
    echo \"🔌 Testing connection...\"
    send_command \"connect\" \"connect\" \"{}\"
    echo \"✅ Connected\"
}

function test_disconnect() {
    echo \"🔌 Disconnecting...\"
    send_command \"disconnect\" \"disconnect\" \"{}\"
    echo \"✅ Disconnected\"
}

function test_read_slot() {
    local slot=$1
    echo \"📖 Reading preset slot $slot...\"
    local params=\"{\\\"index\\\":$slot}\"
    send_command \"read_$slot\" \"readPresetSlot\" \"$params\"
}

function test_write_slot() {
    local slot=$1
    local name=\"$2\"
    local filmsim=$3
    local dr=$4
    local grain=$5
    
    echo \"✍️  Writing preset slot $slot...\"
    local params=\"{\\\"index\\\":$slot,\\\"data\\\":{\\\"name\\\":\\\"$name\\\",\\\"filmSimulation\\\":$filmsim,\\\"dynamicRange\\\":$dr,\\\"grainEffect\\\":$grain}}\"
    send_command \"write_$slot\" \"writePresetSlot\" \"$params\"
}

function test_list_slots() {
    echo \"📋 Reading all preset slots...\"
    for i in {1..7}; do
        echo \"\"
        echo \"─ Slot C$i:\"
        test_read_slot \"$i\" 2>/dev/null | head -5 || true
    done
}

function test_full() {
    test_connect
    echo \"\"
    echo \"Reading slot C1...\"
    test_read_slot \"1\"
    echo \"\"
    echo \"Writing test preset to slot C1...\"
    test_write_slot \"1\" \"TestPreset\" \"1\" \"2\" \"0\"
    echo \"\"
    echo \"Reading slot C1 again to verify...\"
    test_read_slot \"1\"
    test_disconnect
}

# Command routing
case \"${1:-help}\" in
    connect)
        test_connect
        ;;
    disconnect)
        test_disconnect
        ;;
    list)
        test_list_slots
        ;;
    read)
        if [ -z \"$2\" ]; then
            echo \"Usage: $0 read <slot>\"
            exit 1
        fi
        test_connect
        test_read_slot \"$2\"
        test_disconnect
        ;;
    write)
        if [ -z \"$5\" ]; then
            echo \"Usage: $0 write <slot> <name> <filmsim> <dr> <grain>\"
            exit 1
        fi
        test_connect
        test_write_slot \"$2\" \"$3\" \"$4\" \"$5\" \"${6:-0}\"
        test_disconnect
        ;;
    full)
        test_full
        ;;
    *)
        echo \"libgphoto2 Preset Slot Tester\"
        echo \"Usage: $0 <command> [args...]\"
        echo \"\"
        echo \"Commands:\"
        echo \"  connect              Test camera connection\"
        echo \"  disconnect           Disconnect from camera\"
        echo \"  list                 List all preset slots\"
        echo \"  read <slot>          Read preset from slot (1-7)\"
        echo \"  write <slot> <name> <fs> <dr> <grain>  Write preset to slot\"
        echo \"  full                 Run full test (connect, read, write, disconnect)\"
        echo \"\"
        echo \"Examples:\"
        echo \"  $0 connect\"
        echo \"  $0 read 1\"
        echo \"  $0 write 1 MyPreset 1 2 0\"
        echo \"  $0 list\"
        echo \"  $0 full\"
        ;;
esac
