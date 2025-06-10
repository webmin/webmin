# html-editor-lib.pl
# Quill HTML editor related subs

sub html_editor_load_bundle
{
my ($opts) = @_;
$opts ||= {};
my $html_editor_load_scripts;

# Load extra modules first
$html_editor_load_scripts .=
    &html_editor_load_modules($opts);

# Load Quill HTML editor files
$html_editor_load_scripts .=
<<EOF;
<link href="$opts->{'_'}->{'web'}->{'prefix'}/unauthenticated/css/quill.min.css?$opts->{'_'}->{'web'}->{'timestamp'}" rel="stylesheet">
<script type="text/javascript" src="$opts->{'_'}->{'web'}->{'prefix'}/unauthenticated/js/quill.min.js?$opts->{'_'}->{'web'}->{'timestamp'}"></script>
EOF

return $html_editor_load_scripts;
}
sub html_editor_load_modules
{
my ($opts) = @_;
my $html_editor_load_modules;
my $load_css_modules = sub {
    my ($css_modules) = @_;
    foreach my $module (@{$css_modules}) {
        $html_editor_load_modules .=
            "<link href='$opts->{'_'}->{'web'}->{'prefix'}/unauthenticated/css/$module.min.css?$opts->{'_'}->{'web'}->{'timestamp'}' rel='stylesheet'>\n";
        }
    };
my $load_js_modules = sub {
    my ($js_modules) = @_;
    foreach my $module (@{$js_modules}) {
        $html_editor_load_modules .=
            "<script type='text/javascript' src='$opts->{'_'}->{'web'}->{'prefix'}/unauthenticated/js/$module.min.js?$opts->{'_'}->{'web'}->{'timestamp'}'></script>\n";
        }
    };

# Load extra CSS modules
if ($opts->{'extra'}->{'css'}) {
    &$load_css_modules($opts->{'extra'}->{'css'})
    }
    
# Load extra JS modules
if ($opts->{'extra'}->{'js'}) {
    &$load_js_modules($opts->{'extra'}->{'js'})
    }

# Automatically load dependencies
# based on editor mode
if ($opts->{'type'} eq "advanced") {
    my $highlight_bundle = ['highlight/highlight'];
    my @highlight_bundle = @{$highlight_bundle};
    if ($opts->{'_'}->{'client'}->{'palette'} eq 'dark') {
        foreach (@highlight_bundle) {
            $_ .= "-dark"
                if (-e "$root_directory/unauthenticated/css/$_-dark.min.css");
            }
        }
    &$load_css_modules(\@highlight_bundle);
    &$load_js_modules($highlight_bundle);
    }
return $html_editor_load_modules;
}

sub html_editor_template
{
my ($opts) = @_;
$opts ||= {};
$html_editor_template =
<<EOF;
    $opts->{'before'}->{'container'}
    <div class="ql-compose-container $opts->{'class'}->{'container'}">
        $opts->{'before'}->{'editor'}
        <div data-composer="html" class="ql-compose ql-container $opts->{'class'}->{'editor'}"></div>
        $opts->{'after'}->{'editor'}
    </div>
    $opts->{'after'}->{'container'}
EOF
return $html_editor_template;
}
sub html_editor_styles
{
my ($type) = @_;

# HTML editor toolbar styles
if ($type eq 'toolbar') {
    return
<<EOF;
<style>
    .ql-compose-container .ql-snow .ql-formats:empty {
        display: none;
    }
    .ql-compose-container .ql-snow .ql-picker.ql-font .ql-picker-label::before,
    .ql-compose-container .ql-snow .ql-picker.ql-font .ql-picker-item::before {
        content: '$text{'editor_fontfamily_default'}';
    }
    .ql-compose-container .ql-snow .ql-picker.ql-font .ql-picker-label[data-value="monospace"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-font .ql-picker-item[data-value="monospace"]::before {
        content: '$text{'editor_fontfamily_monospace'}';
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-label[data-value="0.75em"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item[data-value="0.75em"]::before {
        content: '$text{'editor_font_small'}';
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item[data-value="0.75em"]::before {
        font-size: 0.75em;
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-label::before,
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item::before {
        content: '$text{'editor_font_normal'}';
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item::before {
        font-size: 1em;
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-label[data-value="1.15em"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item[data-value="1.15em"]::before {
        content: '$text{'editor_font_medium'}';
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item[data-value="1.15em"]::before {
        font-size: 1.15em;
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-label[data-value="1.3em"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item[data-value="1.3em"]::before {
        content: '$text{'editor_font_large'}';
    }
    .ql-compose-container .ql-snow .ql-picker.ql-size .ql-picker-item[data-value="1.3em"]::before {
        font-size: 1.3em;
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item::before {
        content: '$text{'editor_paragraph'}';
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label[data-value="1"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item[data-value="1"]::before {
        content: '$text{'editor_heading'} 1'
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label[data-value="2"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item[data-value="2"]::before {
        content: '$text{'editor_heading'} 2'
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label[data-value="3"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item[data-value="3"]::before {
        content: '$text{'editor_heading'} 3'
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label[data-value="4"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item[data-value="4"]::before {
        content: '$text{'editor_heading'} 4'
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label[data-value="5"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item[data-value="5"]::before {
        content: '$text{'editor_heading'} 5'
    }

    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-label[data-value="6"]::before,
    .ql-compose-container .ql-snow .ql-picker.ql-header .ql-picker-item[data-value="6"]::before {
        content: '$text{'editor_heading'} 6'
    }
</style>
EOF
    }
}

sub html_editor_toolbar
{
my ($opts) = @_;

# Toolbar modes
if ($opts->{'type'} eq 'basic') {
    return 
<<EOF;
  [
    ['bold', 'italic'],
    [{'color': []}],
    ['blockquote']
  ]
EOF
    }
if ($opts->{'type'} eq 'simple') {
    return 
<<EOF;
  [
    [{'font': [false, 'monospace']},
     {'size': ['0.75em', false, "1.15em", '1.3em']}],
    ['bold', 'italic', 'underline'],
    [{'color': []}, {'background': []}],
    [{'align': []}],
    ['blockquote'],
    ['link'],
    ['image'],
    ['clean']
  ]
EOF
    }
if ($opts->{'type'} eq 'advanced') {
    return 
<<EOF;
  [
    [{'font': [false, 'monospace']},
     {'size': ['0.75em', false, "1.15em", '1.3em']},
     {'header': [1, 2, 3, 4, 5, 6, false]}],
    ['bold', 'italic', 'underline', 'strike'],
    [{'script': 'sub'}, {'script': 'super'}],
    [{'color': []}, {'background': []}],
    [{'align': []}],
    [{'list': 'ordered'}, {'list': 'bullet'}],
    [{'indent': '-1'}, {'indent': '+1'}],
    ['blockquote'],
    (typeof hljs === 'object' ? ['code-block'] : []),
    ['link'],
    ['image'],
    [{'direction': 'rtl'}],
    ['clean']
  ]
EOF
    }
}

sub html_editor_init_script
{
my ($opts) = @_;
# Get target name and selector type
my $target_text = $opts->{'textarea'}->{'target'};
my $target_attr = $target_text->{'attr'} || 'name';
my $target_type = $target_text->{'type'} || '=';
my $target_name = $target_text->{'name'};

# HTML editor toolbar mode
my $iframe_styles_mode = $opts->{'type'};
my $iframe_styles = 
  &quote_escape(
    &read_file_contents("$root_directory/unauthenticated/css/_iframe/$iframe_styles_mode.min.css"), '"');
$iframe_styles =~ s/\n/ /g;
my $navigation_type = $ENV{'HTTP_X_NAVIGATION_TYPE'};
$navigation_type ||= 'reload';
my $html_editor_init_script =
<<EOF;
<script type="text/javascript">
  function fn_${module_name}_quote_mail_iframe_loaded() {
    const editor = fn_${module_name}_html_editor_init.editor;
    editor.root.innerHTML = "\\n" + editor.root.innerHTML;
    fn_${module_name}_quote_mail_iframe_loaded = null;
  }
  function fn_${module_name}_html_editor_init() {
    const targ = document.querySelector('[$target_attr$target_type"$target_name"]'),
      qs = Quill.import('attributors/style/size'),
      qf = Quill.import('attributors/style/font'),
      isMac = navigator.userAgent.toLowerCase().includes('mac'),
      navigation_type = '$navigation_type',
      iframe_styles = "$iframe_styles";

    qs.whitelist = ["0.75em", "1.15em", "1.3em"];
    Quill.register(qs, true);
    qf.whitelist = ["monospace"],
    Quill.register(qf, true);

    const editor = new Quill('.ql-container', {
        modules: {
            syntax: typeof hljs === 'object',
            imageDrop: true,
            imageResize: {
                modules: [
                    'DisplaySize',
                    'Resize',
                ],
            },
            clipboard: {
              matchVisual: false
            },
            toolbar: @{[&html_editor_toolbar($opts)]},
        },
        bounds: '.ql-compose-container',
        theme: 'snow'
    });

    fn_${module_name}_html_editor_init.editor = editor;

    // Google Mail like key bind for creating numbered list (Ctrl+Shift+7)
    editor.keyboard.addBinding({
        key: '7',
        shiftKey: true,
        ctrlKey: !isMac,
        metaKey: isMac,
    }, function(range, context) {
        const currentFormat = this.quill.getFormat(range.index);
        if (currentFormat.list === 'ordered') {
            this.quill.format('list', false);
        } else {
            this.quill.format('list', 'ordered');
        }
    });

    // Google Mail like key bind for creating bullet list (Ctrl+Shift+8)
    editor.keyboard.addBinding({
        key: '8',
        shiftKey: true,
        ctrlKey: !isMac,
        metaKey: isMac,
    }, function(range, context) {
        const currentFormat = this.quill.getFormat(range.index);
        if (currentFormat.list === 'bullet') {
            this.quill.format('list', false);
        } else {
            this.quill.format('list', 'bullet');
        }
    });

    // Google Mail like key bind for creating blockquote (Ctrl+Shift+9)
    editor.keyboard.addBinding({
        key: '9',
        shiftKey: true,
        ctrlKey: !isMac,
        metaKey: isMac,
    }, function(range, context) {
        const currentFormat = this.quill.getFormat(range.index);
        if (currentFormat.blockquote) {
            this.quill.format('blockquote', false);
        } else {
            this.quill.format('blockquote', true);
        }
    });

    editor.on('text-change', function() {
        // This should most probably go to onSubmit event
        targ.value = editor.root.innerHTML + "<br>";
        sessionStorage.setItem('$module_name/quill=last-message', editor.root.innerHTML);
        let extraValue = String(),
            sync = JSON.parse('@{[&convert_to_json($opts->{'textarea'}->{'sync'}->{'data'})]}'),
            position = '@{[$opts->{'textarea'}->{'sync'}->{'position'}]}',
            err = false;
        try {
            // Gather data from additional elements if given
            if (sync.constructor === Array) {
                sync.forEach(function(_) {
                    let content_document = document;
                    if (_.iframe) {
                        content_document =
                          document.querySelector(_.iframe).contentWindow.document;
                    }
                    _.elements.forEach(function(element) {
                        const element_ = content_document.querySelector(element);
                        (element_ && (extraValue += element_.innerHTML));
                    })
                });
            }
        } catch(e) {
          err = true;
        }
        if (!err) {
          if (position === 'before') {
            targ.value = extraValue + targ.value;
          } else {
            targ.value = targ.value + extraValue;
          }
        }
        // Inject our styles (unless already injected) to be sent alongside
        // with the message. These styles later can be optionally turned in
        // inline styling to satisfy GMail strict rules about HTML emails
        if (!targ.value.match(/data-iframe-mode=(.*?)$iframe_styles_mode(.*?)/)) {
            targ.value = targ.value +
              '<style data-iframe-mode="$iframe_styles_mode">' + iframe_styles + '</style>';
        }
    });
    
    // Prevent loosing focus for toolbar selects (color picker, font select and etc)
    editor.getModule("toolbar").container.addEventListener("mousedown", (e) => {
      e.preventDefault();
    });

    // Don't loose message content if the page 
    // is reloaded or history back is clicked
    let restore_message = false;
    try {
        restore_message = window.performance.getEntriesByType("navigation")[0].type !== 'navigate' &&
                          navigation_type !== 'navigate'
    } catch(e) {
      restore_message = false;
    }
    if (restore_message) {
        const quill_last_message = sessionStorage.getItem('$module_name/quill=last-message');
        if (quill_last_message) {
            editor.pasteHTML(quill_last_message);
            return;
        }
    }

    // Update editor on initial load
    editor.pasteHTML(targ.value);
    sessionStorage.setItem('$module_name/quill=last-message', editor.root.innerHTML);
  }
  @{[$opts->{'load'} ? "fn_${module_name}_html_editor_init()" : '']}
</script>
EOF
return $html_editor_init_script;
}

sub html_editor
{
my ($opts) = @_;

# Populate defaults
&html_editor_opts_populate_defaults($opts);

# Get template
my $html_editor_template =
     &html_editor_template($opts);
# Get toolbar styling
my $html_editor_styles_toolbar =
     &html_editor_styles('toolbar');
# Load bundles
my ($html_editor_load_scripts);
my %tinfo = &get_theme_info($current_theme);
if (!$tinfo{'spa'}) {
    # Load HTML editor files and dependencies
    $html_editor_load_scripts =
        &html_editor_load_bundle($opts);
    }

# HTML editor init
$opts->{'load'} = !$tinfo{'spa'};
my $html_editor_init_scripts =
    &html_editor_init_script($opts);

# Return complete HTML editor
return $html_editor_template .
       $html_editor_styles_toolbar .
       $html_editor_load_scripts .
       $html_editor_init_scripts;
}

sub html_editor_opts_populate_defaults
{
my ($opts) = @_;
# Miniserv webprefix
$opts->{'_'}->{'web'}->{'prefix'} = &get_webprefix();
# Webmin version to timestamp
my $webmin_version = &get_webmin_version();
$webmin_version =~ s/[.-]+//g;
$opts->{'_'}->{'web'}->{'timestamp'} = $webmin_version;
# Client color palette
$opts->{'_'}->{'client'}->{'palette'} = $ENV{'HTTP_X_COLOR_PALETTE'};
}

sub html_editor_substitute_classes_with_styles
{
my ($styled_html_email) = @_;
my ($document_styles_string) = $styled_html_email =~ /<style\s+data-iframe-mode.*?>(.*)<\/style>/;
if ($document_styles_string) {
    my (%document_styles_class_names) =
          $document_styles_string =~ /(\.[\w\-\_\d\,\.]+)\s*\{\s*([^}]*?)\s*\}/migx;
    my $class_string = sub {
        return "class=\"$_[0]\"";
    };
    my $style_string = sub {
        return "style=\"$_[0]\"";
    };

    my $style_format = sub {
        my ($stl) = @_;
        # Format style nicely, as Google Mail insists
        # on having these formatted neatly
        $stl =~ s/(:|;)\s*/$1 /g;
        $stl =~ s/(?<!;)$/;/g;
        $stl =~ s/[;\s]+$/;/g;
        $stl =~ s/(\S)(\!important)/$1 $2/g;
        $stl =~ s/\s+$//;
        return $stl;
    };
    # Replace tags classes with inline styles
    foreach my $classes (reverse sort { length($a) <=> length($b) } keys %document_styles_class_names) {
        my @classes = split(/\s*,\s*/, $classes);
        foreach my $class (reverse sort { length($a) <=> length($b) } @classes) {
            my (@class_parts) = $class =~ /\.([\S][^\.]+)/migx;
            my (@style_exact_full) = 
                               map { &$style_format($document_styles_class_names{$_}) }
                                 grep { $_ =~ /(?<!\.)(\Q$class\E)(?!\.)(?!\-)(?!\_)/}
                                   keys %document_styles_class_names;
            # Class full
            if (@style_exact_full) {
                my $r = &$class_string("@class_parts");
                my $s = &$style_string("@style_exact_full");
                $styled_html_email =~ s/\Q$r\E/$s/migx;
                }

            # Class parts
            $class =~ s/^\.//g;
            if ("@class_parts" ne $class) {
                foreach my $class_part (@class_parts) {
                    my $style_exact_part = $document_styles_class_names{".$class_part"};
                    if ($style_exact_part) {
                        $style_exact_part = &$style_format($style_exact_part);
                        my $r = &$class_string($class_part);
                        my $s = &$style_string($style_exact_part);
                        $styled_html_email =~ s/\Q$r\E/$s/migx;
                        }
                    }
                }
            }
        }
    # Fill tags with our inline styles
    my (@document_styles_tag_names) = $styled_html_email =~ /<(?!style)(?!script)(?!s)(\w+)\s*.*?>/migx;
    foreach my $tag_name (&unique(@document_styles_tag_names)) {
        my (%document_styles_tag_names) = $document_styles_string =~ /(\Q$tag_name\E)\s*\{\s*([^}]*?)\s*\}/migx;
        foreach my $tag (keys %document_styles_tag_names) {
            my $tag_style = &$style_format($document_styles_tag_names{$tag});
            $styled_html_email =~ s/(<$tag)(?![^>]+style).*?>/$1 style="$tag_style">/mig;
            }
        }
    }
return $styled_html_email;
}

1;