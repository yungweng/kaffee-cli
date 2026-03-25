function plug --description "HomeKit Smart Plugs steuern"
    set -l app_path (_plug_find_app)

    if test -z "$app_path"
        echo "Fehler: HomeKitBridge.app nicht gefunden. Bitte erst bauen." >&2
        return 1
    end

    if not test -d "$app_path"
        echo "Fehler: HomeKitBridge.app nicht gefunden: $app_path" >&2
        return 1
    end

    set -l tmp_dir (mktemp -d /tmp/homekit-bridge.XXXXXX)
    if test -z "$tmp_dir"
        echo "Fehler: Konnte kein temporäres Verzeichnis erstellen." >&2
        return 1
    end

    set -l cmd_file "$tmp_dir/command.json"
    set -l out_file "$tmp_dir/output.json"

    # Usage: plug [device] [an|aus|status|toggle]
    #        plug list
    if not set -q argv[1]; or test "$argv[1]" = list
        _plug_write_command $cmd_file list; or begin
            _plug_cleanup $tmp_dir
            return 1
        end

        _plug_run_bridge "$app_path" "$cmd_file" "$out_file"; or begin
            echo "Fehler: Keine Antwort von HomeKitBridge" >&2
            _plug_cleanup $tmp_dir
            return 1
        end

        python3 -c "
import json, sys

with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
if 'error' in data:
    print(f'Fehler: {data.get(\"message\", data[\"error\"])}', file=sys.stderr)
    sys.exit(1)
show_home = len({d.get('home', '') for d in data['devices']}) > 1
for d in sorted(data['devices'], key=lambda x: (x.get('home', ''), x['room'], x['name'])):
    icon = '🟢' if d['on'] else '⚫'
    reach = '' if d['reachable'] else ' (nicht erreichbar)'
    location = f\"{d.get('home', '')} / {d['room']}\" if show_home else d['room']
    print(f'{icon} {location:25s} {d[\"name\"]}{reach}')
" $out_file
        set -l status $status
        _plug_cleanup $tmp_dir
        return $status
    end

    set -l device $argv[1]
    set -l action toggle

    if set -q argv[2]
        set action $argv[2]
    end

    switch "$action"
        case an on
            _plug_write_command $cmd_file set $device true
        case aus off
            _plug_write_command $cmd_file set $device false
        case status get
            _plug_write_command $cmd_file get $device
        case toggle
            _plug_write_command $cmd_file toggle $device
        case '*'
            echo "Usage: plug [device] [an|aus|status|toggle]"
            echo "       plug list"
            _plug_cleanup $tmp_dir
            return 1
    end

    if test $status -ne 0
        _plug_cleanup $tmp_dir
        return 1
    end

    _plug_run_bridge "$app_path" "$cmd_file" "$out_file"; or begin
        echo "Fehler: Keine Antwort von HomeKitBridge" >&2
        _plug_cleanup $tmp_dir
        return 1
    end

    set -l result (python3 -c "
import json, sys

with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
if 'error' in data:
    print(f'error:{data.get(\"message\", data[\"error\"])}')
    sys.exit(0)
on = data.get('on', False)
print(f'ok:{\"on\" if on else \"off\"}')
" $out_file)

    if string match -q 'error:*' $result
        echo "Fehler: "(string replace 'error:' '' $result) >&2
        _plug_cleanup $tmp_dir
        return 1
    end

    set -l state (string split ':' $result)
    set -l on_off $state[2]
    if test "$on_off" = on
        echo "🟢 $device an"
    else
        echo "⚫ $device aus"
    end

    _plug_cleanup $tmp_dir
end

function _plug_write_command
    python3 -c "
import json, sys

path = sys.argv[1]
action = sys.argv[2]
payload = {'action': action}

if len(sys.argv) >= 4:
    payload['device'] = sys.argv[3]
if len(sys.argv) >= 5:
    payload['value'] = sys.argv[4].lower() == 'true'

with open(path, 'w', encoding='utf-8') as f:
    json.dump(payload, f)
" $argv
end

function _plug_find_app
    set -l app_suffix HomeKitBridge/build/DerivedData/Build/Products/Debug-maccatalyst/HomeKitBridge.app

    if set -q KAFFEE_HOMEKITBRIDGE_APP
        if test -d "$KAFFEE_HOMEKITBRIDGE_APP"
            echo "$KAFFEE_HOMEKITBRIDGE_APP"
            return 0
        end
    end

    set -l search_roots $PWD (status dirname) (dirname (functions -D plug)) $HOME
    for root in $search_roots
        if not test -d "$root"
            continue
        end

        set -l candidate "$root/$app_suffix"
        if test -d "$candidate"
            echo "$candidate"
            return 0
        end

        set -l nested_candidate (find "$root" -path "*/$app_suffix" -print -quit 2>/dev/null)
        if test -n "$nested_candidate"
            echo "$nested_candidate"
            return 0
        end
    end

    find ~/Library/Developer/Xcode/DerivedData -path "*/HomeKitBridge-*/Build/Products/Debug-maccatalyst/HomeKitBridge.app" -maxdepth 5 2>/dev/null | head -1
end

function _plug_run_bridge
    set -l app_path $argv[1]
    set -l cmd_file $argv[2]
    set -l out_file $argv[3]

    command open -gj "$app_path" --args "$cmd_file" "$out_file" >/dev/null 2>&1
    or return 1

    _plug_wait_output "$out_file"
end

function _plug_wait_output
    set -l out_file $argv[1]
    set -l max_attempts 120

    for _ in (seq $max_attempts)
        if test -s "$out_file"
            return 0
        end

        sleep 0.1
    end

    return 1
end

function _plug_cleanup
    if set -q argv[1]; and test -n "$argv[1]"
        rm -rf $argv[1]
    end
end
