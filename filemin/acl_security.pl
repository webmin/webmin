require 'filemin-lib.pl';

sub acl_security_form {
    my ($access) = @_;

    # Directories the user can access
    print &ui_table_row($text{'acl_allowed_paths'}."<br>\n".
			$text{'acl_allowed_paths2'},
	ui_textarea("allowed_paths",
		    join("\n", split(/\s+/, $access->{'allowed_paths'})),
		    10, 80, undef, undef, "style='width: 100%'"), 2);

    # Mimetypes allowed to be edited
    print &ui_table_row($text{'acl_allowed_for_edit'},
	ui_textarea("allowed_for_edit",
		    join("\n", split(/\s+/, $access->{'allowed_for_edit'})),
		    10, 80, undef, undef, "style='width: 100%'"), 2);

    # Run as Unix user
    print &ui_table_row($text{'acl_work_as'},
	ui_radio_table("user_mode", $access->{'work_as_root'} ? 0 :
			            $access->{'work_as_user'} ? 2 : 1,
	       [ [ 0, $text{'acl_root'} ],
		 [ 1, $text{'acl_same'} ],
		 [ 2, $text{'acl_user'},
		   ui_user_textbox("acl_user", $access->{'work_as_user'}) ] ]),
	3);

    # Upload max
    print &ui_table_row($text{'acl_max'},
	&ui_opt_textbox("max", $access->{'max'}, 10, $text{'acl_unlimited'}).
	" ".$text{'acl_bytes'}, 3);
}

sub acl_security_save {
    my ($access, $in) = @_;
    local @allowed_paths = split(/\s+/, $in->{'allowed_paths'});
    if (scalar(@allowed_paths) == 0) { &error("No allowed paths defined"); }
    for $path(@allowed_paths) {
        if (!-e $path && $path ne '$HOME' && $path ne '$ROOT') {
            &error(&text('acl_epath', &html_escape($path)));
        }
    }
    $access->{'allowed_paths'} = join(" ", @allowed_paths);

    local @allowed_for_edit = split(/\s+/, $in->{'allowed_for_edit'});
    if (scalar(@allowed_for_edit) == 0) { &error("No mimetypes allowed for edit defined"); }
    $access->{'allowed_for_edit'} = join(" ", @allowed_for_edit);

    if ($in->{'user_mode'} == 0) {
        $access->{'work_as_root'} = 1;
        $access->{'work_as_user'} = undef;
    } elsif ($in->{'user_mode'} == 1) {
        $access->{'work_as_root'} = 0;
        $access->{'work_as_user'} = undef;
    } else {
	defined(getpwnam($in->{'acl_user'})) || &error($text{'acl_euser'});
        $access->{'work_as_root'} = 0;
        $access->{'work_as_user'} = $in->{'acl_user'};
    }
    $access->{'max'} = $in->{'max_def'} ? undef : $in{'max'};
}
