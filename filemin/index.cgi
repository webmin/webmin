#!/usr/local/bin/perl
# File manager written in perl

#$unsafe_index_cgi = 1;
require './filemin-lib.pl';
use lib './lib';
#use File::Basename;
use File::MimeInfo;

&ReadParse();

get_paths();

unless (opendir ( DIR, $cwd )) {
    $path="";
    print_errors("$text{'error_opendir'} $cwd $!");
} else {
    &ui_print_header(undef, "Filemin", "", undef, 0 , 0, 0, "<a href='config.cgi?path=$path' data-config-pagination='$userconfig{'per_page'}'>$text{'module_config'}</a>");

##########################################
#---------LET DA BRAINF###ING BEGIN----------
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
    # Get info about directory entries
    @info = map { [ $_, stat($_), &mimetype($_), -d $_ ] } @list;

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

#########################################

    print_interface();

    &ui_print_footer("/", $text{'index'});
}
