#!/usr/local/bin/perl
# File manager written in perl

require './filemin-lib.pl';
use lib './lib';

use File::MimeInfo;

&ReadParse();
get_paths();

unless (opendir ( DIR, $cwd )) {
    $path="";
    print_errors($text{'error_opendir'}." ".&html_escape($cwd)." ".$!);
} else {
    &ui_print_header(undef, $module_info{'name'}, "", undef, 0 , 0, 0, "<a href='config.cgi?path=".&urlize($path)."' data-config-pagination='$userconfig{'per_page'}'>$text{'module_config'}</a>");

    my $setype = get_selinux_command_type();
    my %secontext;
    my %attributes;

    # Push file names with full paths to array, filtering out "." and ".."
    @list = map { &simplify_path("$cwd/$_") } grep { $_ ne '.' && $_ ne '..' } readdir(DIR);
    closedir(DIR);

    # Filter out not allowed entries
    if($remote_user_info[0] ne 'root' && $allowed_paths[0] ne '$ROOT') {
        # Leave only allowed
        for $path (@allowed_paths) {
            my $slashed = $path;
            $slashed .= "/" if ($slashed !~ /\/$/);
            push @tmp_list, grep { $slashed =~ /^$_\// ||
                                   $_ =~ /$slashed/ } @list;
        }
        # Remove duplicates
        my %hash = map { $_, 1 } @tmp_list;
        @list = keys %hash;
    }

    # List attributes
    if ( $userconfig{'columns'} =~ /attributes/ && get_attr_status() ) {
        my $command = get_attr_command() . join( ' ', map { quotemeta("$_") } @list );
        my $output = `$command`;
        my @attributesArr =
          map { [ split( /\s+/, $_, 2 ) ] } split( /\n/, $output );
        %attributes = map { $_->[1] => ('<span data-attributes="x">' . $_->[0] . '</span>') } @attributesArr;
    }

    # List security context
    if ( $userconfig{'columns'} =~ /selinux/ && get_selinux_status() ) {
        my $command = get_selinux_command() . join( ' ', map { quotemeta("$_") } @list );
        my $output = `$command`;
        ( !$setype && ( $output =~ s/\n//g, $output =~ s/,\s/,/g ) );
        my $delimiter = ( $setype ? '\n' : ',' );
        my @searray =
          map { [ split( /\s+/, $_, 2 ) ] } split( /$delimiter/, $output );
        %secontext = map { $_->[1] => ($_->[0] eq "?" ? undef : ('<span data-attributes="x">' . $_->[0] . '</span>') ) } @searray;
    }

    # Get info about directory entries
    @info = map { [ $_, lstat($_), &mimetype($_), -d, -l $_, $secontext{$_}, $attributes{$_} ] } @list;

    # Filter out folders
    @folders = map {$_} grep {$_->[15] == 1 } @info;

    # Filter out files
    @files = map {$_} grep {$_->[15] != 1 } @info;

    # Sort stuff by name
    @folders = sort { $a->[0] cmp $b->[0] } @folders;
    @files = sort { $a->[0] cmp $b->[0] } @files;

    # Recreate list
    undef(@list);
    push @list, @folders, @files;

    print_interface();
    &ui_print_footer("/", $text{'index'});
}
