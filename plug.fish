function plug --description "HomeKit Smart Plugs steuern"
    set -l app_path (find ~/Library/Developer/Xcode/DerivedData -path "*/HomeKitBridge-*/Build/Products/Debug-maccatalyst/HomeKitBridge.app" -maxdepth 5 2>/dev/null | head -1)
    set -l cmd_file /tmp/homekit-bridge-command.json
    set -l out_file /tmp/homekit-bridge-output.json

    if test -z "$app_path"
        echo "Fehler: HomeKitBridge.app nicht gefunden. Bitte erst bauen." >&2
        return 1
    end

    # Usage: plug [device] [an|aus|status|toggle]
    #        plug list
    if not set -q argv[1]; or test "$argv[1]" = list
        echo '{"action": "list"}' >$cmd_file
        rm -f $out_file
        open -gj "$app_path"
        _plug_wait_output; or return 1

        # Pretty-print device list
        python3 -c "
import json, sys
with open('$out_file') as f:
    data = json.load(f)
if 'error' in data:
    print(f'Fehler: {data.get(\"message\", data[\"error\"])}', file=sys.stderr)
    sys.exit(1)
for d in sorted(data['devices'], key=lambda x: (x['room'], x['name'])):
    icon = '🟢' if d['on'] else '⚫'
    reach = '' if d['reachable'] else ' (nicht erreichbar)'
    print(f'{icon} {d[\"room\"]:15s} {d[\"name\"]}{reach}')
"
        return
    end

    set -l device $argv[1]
    set -l action toggle

    if set -q argv[2]
        set action $argv[2]
    end

    switch "$action"
        case an on
            echo "{\"action\": \"set\", \"device\": \"$device\", \"value\": true}" >$cmd_file
        case aus off
            echo "{\"action\": \"set\", \"device\": \"$device\", \"value\": false}" >$cmd_file
        case status get
            echo "{\"action\": \"get\", \"device\": \"$device\"}" >$cmd_file
        case toggle
            echo "{\"action\": \"toggle\", \"device\": \"$device\"}" >$cmd_file
        case '*'
            echo "Usage: plug [device] [an|aus|status|toggle]"
            echo "       plug list"
            return 1
    end

    rm -f $out_file
    open "$app_path"
    _plug_wait_output; or return 1

    # Parse result
    set -l result (python3 -c "
import json, sys
with open('$out_file') as f:
    data = json.load(f)
if 'error' in data:
    print(f'error:{data.get(\"message\", data[\"error\"])}')
    sys.exit(0)
on = data.get('on', False)
toggled = data.get('toggled', False)
print(f'ok:{\"on\" if on else \"off\"}:{\"toggled\" if toggled else \"set\"}')
")

    if string match -q 'error:*' $result
        echo "Fehler: "(string replace 'error:' '' $result) >&2
        return 1
    end

    set -l state (string split ':' $result)
    set -l on_off $state[2]
    if test "$on_off" = on
        echo "🟢 $device an"
    else
        echo "⚫ $device aus"
    end
end

function _plug_wait_output
    set -l out_file /tmp/homekit-bridge-output.json
    set -l tries 0
    while not test -f $out_file; and test $tries -lt 20
        sleep 0.3
        set tries (math $tries + 1)
    end
    if not test -f $out_file
        echo "Fehler: Timeout - keine Antwort von HomeKitBridge" >&2
        return 1
    end
end

# Convenience aliases
function kaffee --description "Kaffeemaschine steuern"
    if not set -q argv[1]
        plug Kaffee toggle
    else
        plug Kaffee $argv[1]
    end
end
