
Xinha.PanelDialog = function(editor, side, html, localizer)
{
  this.id    = { };
  this.r_id  = { }; // reverse lookup id
  this.editor   = editor;
  this.document = document;
  this.rootElem = editor.addPanel(side);

  var dialog = this;
  if(typeof localizer == 'function')
  {
    this._lc = localizer;
  }
  else if(localizer)
  {
    this._lc = function(string)
    {
      return Xinha._lc(string,localizer);
    };
  }
  else
  {
    this._lc = function(string)
    {
      return string;
    };
  }

  html = html.replace(/\[([a-z0-9_]+)\]/ig,
                      function(fullString, id)
                      {
                        if(typeof dialog.id[id] == 'undefined')
                        {
                          dialog.id[id] = Xinha.uniq('Dialog');
                          dialog.r_id[dialog.id[id]] = id;
                        }
                        return dialog.id[id];
                      }
             ).replace(/<l10n>(.*?)<\/l10n>/ig,
                       function(fullString,translate)
                       {
                         return dialog._lc(translate) ;
                       }
             ).replace(/="_\((.*?)\)"/g,
                       function(fullString, translate)
                       {
                         return '="' + dialog._lc(translate) + '"';
                       }
             );

  this.rootElem.innerHTML = html;
};

Xinha.PanelDialog.prototype.show = function(values)
{
  this.setValues(values);
  this.editor.showPanel(this.rootElem);
};

Xinha.PanelDialog.prototype.hide = function()
{
  this.editor.hidePanel(this.rootElem);
  return this.getValues();
};

Xinha.PanelDialog.prototype.onresize   = Xinha.Dialog.prototype.onresize;

Xinha.PanelDialog.prototype.toggle     = Xinha.Dialog.prototype.toggle;

Xinha.PanelDialog.prototype.setValues  = Xinha.Dialog.prototype.setValues;

Xinha.PanelDialog.prototype.getValues  = Xinha.Dialog.prototype.getValues;

Xinha.PanelDialog.prototype.getElementById    = Xinha.Dialog.prototype.getElementById;

Xinha.PanelDialog.prototype.getElementsByName = Xinha.Dialog.prototype.getElementsByName;