# html-editor-lib.pl
# Quill HTML editor related subs

sub html_editor_load_bundle
{
my ($opts) = @_;
$opts ||= {};
my $wp = &get_webprefix();
my $ts = &get_webmin_version();
$ts =~ s/[.-]+//g;
my $html_editor_load_scripts;
# Load extra CSS modules
if ($opts->{'extra'}->{'css'}) {
    foreach my $lib (@{$opts->{'extra'}->{'css'}}) {
        $html_editor_load_scripts .=
        "<link href='$wp/unauthenticated/css/$lib.min.css?$ts' rel='stylesheet'>\n";
        }
    }
# Load extra JS modules
if ($opts->{'extra'}->{'js'}) {
    foreach my $lib (@{$opts->{'extra'}->{'js'}}) {
        $html_editor_load_scripts .=
        "<script type='text/javascript' src='$wp/unauthenticated/js/$lib.min.js?$ts'></script>\n";
        }
    }
# Load Quill HTML editor files
$html_editor_load_scripts .=
<<EOF;
<link href="$wp/unauthenticated/css/quill.min.css?$ts" rel="stylesheet">
<script type="text/javascript" src="$wp/unauthenticated/js/quill.min.js?$ts"></script>
EOF

return $html_editor_load_scripts;
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
    .ql-compose-container .ql-snow .ql-picker.ql-font .ql-picker-label::before,
    .ql-compose-container .ql-snow .ql-picker.ql-font .ql-picker-item::before {
        content: '$text{'editor_fontfamily_default'}';
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

sub html_editor_parts
{
my ($part, $type) = @_;

# Editor toolbars
if ($part eq 'toolbar') {
    # Toolbar for mail editor
    if ($type eq 'mail') {
        return 
<<EOF;
  [
    [{'font': [false, 'monospace']},
     {'size': ['0.75em', false, "1.15em", '1.3em']}],
    ['bold', 'italic', 'underline', 'strike'],
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
    if ($type eq 'full') {
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
    (typeof hljs === 'object' && typeof katex === 'object' ? ['code-block', 'formula'] :
     typeof hljs === 'object' ? ['code-block'] : typeof katex === 'object' ? ['formula'] : []),
    ['link'],
    ['image', 'video'],
    [{'direction': 'rtl'}],
    ['clean']
  ]
EOF
        }
    }
}
sub html_editor_init_script
{
my ($type, $opts) = @_;
$opts ||= {};
my $html_editor_init_script =
<<EOF;
<script type="text/javascript">
  const mail_init_editor = function() {
    const targ = document.querySelector('[name="body"]'),
      qs = Quill.import('attributors/style/size'),
      qf = Quill.import('attributors/style/font'),
      escapeHTML_ = function(htmlStr) {
         return htmlStr.replace(/&/g, "&amp;")
             .replace(/</g, "&lt;")
             .replace(/>/g, "&gt;")
             .replace(/"/g, "&quot;")
             .replace(/'/g, "&#39;");        
      },
      isMac = navigator.userAgent.toLowerCase().includes('mac');

    qs.whitelist = ["0.75em", "1.15em", "1.3em"];
    Quill.register(qs, true);
    qf.whitelist = ["monospace"],
    Quill.register(qf, true);

    // Whitelist attrs
    const pc = Quill.import('parchment'),
          pc_attrs_whitelist =
          [
            'margin', 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
            'padding', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
            'border', 'border-right', 'border-left',
            'font-size', 'font-family', 'href', 'target',
          ]
    pc_attrs_whitelist.forEach(function(attr) {
        Quill.register(new pc.Attributor.Style(attr, attr, {}));
    });

    const editor = new Quill('.ql-container', {
        modules: {
            formula: typeof katex === 'object',
            syntax: typeof hljs === 'object',
            imageDrop: true,
            imageResize: {
                modules: [
                    'DisplaySize',
                    'Resize',
                ],
            },
            toolbar: @{[&html_editor_parts('toolbar', $type)]},
        },
        bounds: '.ql-compose-container',
        theme: 'snow'
    });

    // Google Mail editor like keybind for quoting
    editor.keyboard.addBinding({
      key: '9',
      shiftKey: true,
      ctrlKey: !isMac,
      metaKey: isMac,
      format: ['blockquote'],
    }, function(range, context) {
      this.quill.format('blockquote', false);
    });
    editor.keyboard.addBinding({
      key: '9',
      shiftKey: true,
      ctrlKey: !isMac,
      metaKey: isMac,
    }, function(range, context) {
      this.quill.format('blockquote', true);
    });
    editor.on('text-change', function() {
        targ.value = escapeHTML_(editor.root.innerHTML + "<br><br>");
        let quoteHTML = String(),
              err = false;
        try {
          quoteHTML =
            document.querySelector('#quote-mail-iframe')
              .contentWindow.document
              .querySelector('.iframe_quote[contenteditable]#webmin-iframe-quote').innerHTML;
        } catch(e) {
          err = true;
        }
        if (!err) {
          targ.value = targ.value + escapeHTML_(quoteHTML);
        }
    });
    editor.pasteHTML(targ.value);

    // Prevent loosing focus for toolbar selects (color picker, font select and etc)
    editor.getModule("toolbar").container.addEventListener("mousedown", (e) => {
      e.preventDefault();
    });
  }
  @{[$opts->{'load'} ? 'mail_init_editor()' : '']}
</script>
EOF
return $html_editor_init_script;
}

1;