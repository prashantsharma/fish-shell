
function __fish_print_packages

    # apt-cache is much, much faster than rpm, and can do this in real
    # time. We use it if available.

    switch (commandline -ct)
        case '-**'
            return
    end

    #Get the word 'Package' in the current language
    set -l package (_ "Package")

    # Set up cache directory
    if test -z "$XDG_CACHE_HOME"
        set XDG_CACHE_HOME $HOME/.cache
    end
    mkdir -m 700 -p $XDG_CACHE_HOME

    if type -q -f apt-cache
        # Do not generate the cache as apparently sometimes this is slow.
        # http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=547550
        apt-cache --no-generate pkgnames (commandline -ct) ^/dev/null | sed -e 's/$/'\t$package'/'
        return
    end

    # Pkg is fast on FreeBSD and provides versioning info which we want for
    # installed packages
    if type -q -f pkg
        pkg query "%n-%v"
        return
    end

    # pkg_info on OpenBSD provides versioning info which we want for
    # installed packages but, calling it directly can cause delays in
    # returning information if another pkg_* tool have a lock.
    # Listing /var/db/pkg is a clean alternative.
    if type -q -f pkg_add
        set -l files /var/db/pkg/*
        string replace '/var/db/pkg/' '' -- $files
        return
    end

    # Caches for 5 minutes
    if type -q -f pacman
        set cache_file $XDG_CACHE_HOME/.pac-cache.$USER
        if test -f $cache_file
            cat $cache_file
            set age (math (date +%s) - (stat -c '%Y' $cache_file))
            set max_age 250
            if test $age -lt $max_age
                return
            end
        end

        # prints: <package name>	Package
        pacman -Ssq | sed -e 's/$/\t'$package'/' >$cache_file &
        return
    end

    # Zypper needs caching as it is slow
    if type -q -f zypper
        # Use libzypp cache file if available
        if test -f /var/cache/zypp/solv/@System/solv.idx
            awk '!/application:|srcpackage:|product:|pattern:|patch:/ {print $1'\t$package'}' /var/cache/zypp/solv/*/solv.idx
            return
        end

        # If the cache is less than five minutes old, we do not recalculate it

        set -l cache_file $XDG_CACHE_HOME/.zypper-cache.$USER
        if test -f $cache_file
            cat $cache_file
            set -l age (math (date +%s) - (stat -c '%Y' $cache_file))
            set -l max_age 300
            if test $age -lt $max_age
                return
            end
        end

        # Remove package version information from output and pipe into cache file
        zypper --quiet --non-interactive search --type=package | tail -n +4 | sed -r 's/^. \| ((\w|[-_.])+).*/\1\t'$package'/g' >$cache_file &
        return
    end

    # yum is slow, just like rpm, so go to the background
    if type -q -f /usr/share/yum-cli/completion-helper.py

        # If the cache is less than six hours old, we do not recalculate it

        set cache_file $XDG_CACHE_HOME/.yum-cache.$USER
        if test -f $cache_file
            cat $cache_file
            set age (math (date +%s) - (stat -c '%Y' $cache_file))
            set max_age 21600
            if test $age -lt $max_age
                return
            end
        end

        # Remove package version information from output and pipe into cache file
        /usr/share/yum-cli/completion-helper.py list all -d 0 -C | sed "s/\..*/\t$package/" >$cache_file &
        return
    end

    # Rpm is too slow for this job, so we set it up to do completions
    # as a background job and cache the results.

    if type -q -f rpm

        # If the cache is less than five minutes old, we do not recalculate it

        set cache_file $XDG_CACHE_HOME/.rpm-cache.$USER
        if test -f $cache_file
            cat $cache_file
            set age (math (date +%s) - (stat -c '%Y' $cache_file))
            set max_age 250
            if test $age -lt $max_age
                return
            end
        end

        # Remove package version information from output and pipe into cache file
        rpm -qa | sed -e 's/-[^-]*-[^-]*$/\t'$package'/' >$cache_file &
        return
    end

    # Eopkg is slow in showing list of available packages

    if type -q -f eopkg

        # If the cache is less than max_age, we do not recalculate it

        set cache_file $XDG_CACHE_HOME/.eopkg-cache.$USER
        if test -f $cache_file
            cat $cache_file
            set age (math (date +%s) - (stat -c '%Y' $cache_file))
            set max_age 500
            if test $age -lt $max_age
                return
            end
        end

        # Remove package version information from output and pipe into cache file
        eopkg list-available -N | cut -d ' ' -f 1 >$cache_file &
        return
    end

    # This completes the package name from the portage tree.
    # True for installing new packages. Function for printing
    # installed on the system packages is in completions/emerge.fish

    # eix is MUCH faster than emerge so use it if it is available
    if type -q -f eix
        eix --only-names "^"(commandline -ct) | cut -d/ -f2
        return
    else
        # FIXME?  Seems to be broken
        if type -q -f emerge
            emerge -s \^(commandline -ct) | string match -r "^\*.*" | cut -d' ' -f3 | cut -d/ -f2
            return
        end
    end

    # port needs caching, as it tends to be slow
    # BSD find is used for determining file age because HFS+ and APFS
    # don't save unix time, but the actual date. Also BSD stat is vastly
    # different from linux stat and converting its time format is tedious
    if type -q -f port
        set cache_file $XDG_CACHE_HOME/.port-cache.$USER
        if test -e $cache_file
            # Delete if cache is older than 15 minutes
            find "$cache_file" -ctime +15m | awk '{$1=$1;print}' | xargs rm
            if test -f $cache_file
                cat $cache_file
                return
            end
        end
        # Remove trailing whitespace and pipe into cache file
        printf "all\ncurrent\nactive\ninactive\ninstalled\nuninstalled\noutdated" >$cache_file
        port echo all | awk '{$1=$1};1' >>$cache_file &
        cat $cache_file
        return
    end

end
