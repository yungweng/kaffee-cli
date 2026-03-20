function kaffee --description "Kaffeemaschinen-Steckdose steuern"
    if not set -q argv[1]
        set -l tmpfile (mktemp /tmp/kaffee-status.XXXXXX).txt
        shortcuts run "Kaffee Status" -o $tmpfile 2>/dev/null
        set -l status_now (cat $tmpfile | string trim)
        rm -f $tmpfile
        if test "$status_now" = "an"
            set argv[1] aus
        else
            set argv[1] an
        end
    end

    switch "$argv[1]"
        case an
            shortcuts run "Kaffee an"
            and echo "☕ Kaffee an!"
        case aus
            shortcuts run "Kaffee aus"
            and echo "☕ Kaffee aus!"
        case '*'
            echo "Usage: kaffee [an|aus]"
    end
end
