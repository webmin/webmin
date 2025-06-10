#!/usr/local/bin/perl
# File manager written in perl

require './filemin-lib.pl';

&ReadParse();
get_paths();

unless (opendir ( DIR, $cwd )) {
    $path="";
    print_errors($text{'error_opendir'}." ".&html_escape($cwd)." ".$!);
} else {
    &ui_print_header(undef, $module_info{'name'}, "", undef, 0 , 0, 0, "<a href='config.cgi?path=".&urlize($path)."' data-config-pagination='$userconfig{'per_page'}'>$text{'module_config'}</a>");

    my %acls;
    my %attributes;
    my $setype = get_selinux_command_type();
    my %secontext;

    # Push file names with full paths to array, filtering out "." and ".."
    my $show_dot_files = $userconfig{'config_portable_module_filemanager_show_dot_files'} ne 'false';
    @list = map { &simplify_path("$cwd/$_") } grep { $_ ne '.' && $_ ne '..' && ($show_dot_files || ($_ !~ /^\./ && $_ !~ /\/\./)) } readdir(DIR);
    closedir(DIR);

    # Filter out not allowed paths
    if (&test_allowed_paths()) {
        for $path (@allowed_paths) {
            my $slashed = $path;
            $slashed .= "/" if ($slashed !~ /\/$/);
            push @tmp_list, grep { $slashed =~ /^\Q$_\E\// ||
				   $_ =~ /\Q$slashed\E/ } @list;
        }
        # Remove duplicates
        my %hash = map { $_, 1 } @tmp_list;
        @list = keys %hash;
    }

    # List ACLs
    if ($userconfig{'columns'} =~ /acls/ && get_acls_status()) {
        my $command = get_list_acls_command() . " " . join(' ', map {quotemeta("$_")} @list);
        my $output  = `$command`;
        my @aclsArr;
        foreach my $aclsStr (split(/\n\n/, $output)) {
            $aclsStr =~ /#\s+file:\s*(.*)/;
            my ($file)  = ($aclsStr =~ /#\s+file:\s*(.*)/);
            my @aclsA = ($aclsStr =~ /^(?!(#|user::|group::|other::))([\w\:\-\_]+)/gm);
            push(@aclsArr, [$file, \@aclsA]);
        }
        %acls = map {$_->[0] => ('<span data-acls>' . join("<br>", (grep /\S/, @{ $_->[1] })) . '</span>')} @aclsArr;
    }

    # List attributes
    if ( $userconfig{'columns'} =~ /attributes/ && get_attr_status() ) {
        my $command = get_attr_command() . join( ' ', map { quotemeta("$_") } @list );
        my $output = `$command`;
        my @attributesArr =
          map { [ split( /\s+/, $_, 2 ) ] } split( /\n/, $output );
        %attributes = map { $_->[1] => ('<span data-attributes>' . $_->[0] . '</span>') } @attributesArr;
    }

    # List security context
    if ( $userconfig{'columns'} =~ /selinux/ && get_selinux_status() ) {
        my $command = get_selinux_command() . join( ' ', map { quotemeta("$_") } @list );
        my $output = `$command`;
        ( !$setype && ( $output =~ s/\n//g, $output =~ s/,\s/,/g ) );
        my $delimiter = ( $setype ? '\n' : ',' );
        my @searray =
          map { [ split( /\s+/, $_, 2 ) ] } split( /$delimiter/, $output );
        %secontext = map { $_->[1] => ($_->[0] eq "?" ? undef : ('<span data-secontext>' . $_->[0] . '</span>') ) } @searray;
    }

    # Get info about directory entries
    @info = map { [ $_, lstat($_), &clean_mimetype($_), -d, -l $_, $secontext{$_}, $attributes{$_}, $acls{$_} ] } @list;

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
