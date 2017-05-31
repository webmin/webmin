#!/usr/local/bin/perl

require './filemin-lib.pl';

&ReadParse();

get_paths();

my @errors;

my $perms = $in{'perms'};

# Selected directories and files only
if($in{'applyto'} eq '1') {
    foreach $name (split(/\0/, $in{'name'})) {
        if (system_logged("chmod ".quotemeta($perms)." ".quotemeta("$cwd/$name")) != 0) {
            push @errors, "$name - $text{'error_chmod'}: $?";
        }
    }
}

# Selected files and directories and files in selected directories
if($in{'applyto'} eq '2') {
    foreach $name (split(/\0/, $in{'name'})) {
        if(system_logged("chmod ".quotemeta($perms)." ".quotemeta("$cwd/$name")) != 0) {
            push @errors, "$name - $text{'error_chmod'}: $?";
        }
        if(-d "$cwd/$name") {
            if(system_logged("find ".quotemeta("$cwd/$name")." -maxdepth 1 -type f -exec chmod ".quotemeta($perms)." {} \\;") != 0) {
                push @errors, "$name - $text{'error_chmod'}: $?";
            }
        }
    }
}

# All (recursive)
if($in{'applyto'} eq '3') {
    foreach $name (split(/\0/, $in{'name'})) {
        if(system_logged("chmod -R ".quotemeta($perms)." ".quotemeta("$cwd/$name")) != 0) {
            push @errors, "$name - $text{'error_chmod'}: $?";
        }
    }
}

# Selected files and files under selected directories and subdirectories
if($in{'applyto'} eq '4') {
    foreach $name (split(/\0/, $in{'name'})) {
        if(-f "$cwd/$name") {
            if(system_logged("chmod ".quotemeta($perms)." ".quotemeta("$cwd/$name")) != 0) {
                push @errors, "$name - $text{'error_chmod'}: $?";
            }
        } else {
            if(system_logged("find ".quotemeta("$cwd/$name")." -type f -exec chmod ".quotemeta($perms)." {} \\;") != 0) {
                push @errors, "$name - $text{'error_chmod'}: $?";
            }
        }
    }
}

# Selected directories and subdirectories
if($in{'applyto'} eq '5') {
    foreach $name (split(/\0/, $in{'name'})) {
        if(-d "$cwd/$name") {
            if(system_logged("chmod ".quotemeta($perms)." ".quotemeta("$cwd/$name")) != 0) {
                push @errors, "$name - $text{'error_chmod'}: $?";
            }
            if(system_logged("find ".quotemeta("$cwd/$name")." -type d -exec chmod ".quotemeta($perms)." {} \\;") != 0) {
                push @errors, "$name - $text{'error_chmod'}: $?";
            }
        }
    }
}

if (scalar(@errors) > 0) {
    print_errors(@errors);
} else {
    &redirect("index.cgi?path=".&urlize($path));
}
