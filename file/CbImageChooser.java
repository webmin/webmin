import java.awt.*;
import java.net.*;

class CbImageChooser extends Panel implements CbButtonCallback
{
	Image img;
	String imgsrc;
	int imgw, imgh;
	CbButton but;
	CbImageFileWindow filewin;
	//CbImageChooserCallback callback;

	CbImageChooser(Image i)
	{
	this(i, null);
	}

	CbImageChooser(Image i, String s)
	{
	setLayout(new BorderLayout());
	add("Center", but = new CbButton("Choose..", this));
	setImage(i, s==null ? "" : s);
	}

	void setImage(Image i, String s)
	{
	img = i;
	imgsrc = s;
	if (img != null) but.setImage(img);
	else but.setText("Choose..");
	}

	public void click(CbButton b)
	{
	if (b == but && filewin == null)
		new CbImageFileWindow(this);
	}
}


class CbImageFileWindow extends FixedFrame implements CbButtonCallback
{
	CbImageChooser parent;
	ScrollImage imgp;
	TextField url;
	CbButton browse, ok, cancel;
	FileDialog filedlog;
	String lastfile = "";

	CbImageFileWindow(CbImageChooser p)
	{
	parent = p;
	parent.filewin = this;
	setLayout(new BorderLayout());
	add("Center", imgp = new ScrollImage(parent.img, 200, 200));
	Panel bot = new GrayPanel();
	bot.setLayout(new FlowLayout(FlowLayout.LEFT));
	bot.add(new Label("URL:"));
	bot.add(url = new TextField(parent.imgsrc, 20));
	bot.add(browse = new CbButton("Browse..", this));
	bot.add(new Label("  "));
	bot.add(ok = new CbButton("Ok", this));
	bot.add(cancel = new CbButton("Cancel", this));
	add("South", bot);

	pack();
	show();
	setTitle("Choose Image..");
	Util.recursiveBackground(this, Util.body);
	}

	public void click(CbButton b)
	{
	if (b == ok)
		parent.setImage(imgp.img, lastfile);
	if (b == ok || b == cancel)
		dispose();
	else if (b == browse) {
		// Open file chooser here!
		FileDialog filedlog =
		  new FileDialog(this, "Choose Image",FileDialog.LOAD);
		filedlog.show();
		if (filedlog.getFile() != null) {
			// file chosen.. load it in
			String fn = filedlog.getDirectory()+filedlog.getFile();
			url.setText(fn);
			loadFile(fn);
			}
		}
	}

	public void dispose()
	{
	super.dispose();
	parent.filewin = null;
	}

	public boolean action(Event evt, Object obj)
	{
	if (evt.target == url) {
		String ut = url.getText();
		if (ut.startsWith("http:") || ut.startsWith("ftp:"))
			loadURL(ut);
		else
			loadFile(ut);
		return true;
		}
	return false;
	}

	private void loadFile(String f)
	{
	Image i = Util.tk.getImage(f);
	if (i == null || !Util.waitForImage(i))
		new ErrorWindow("Failed to load image "+f);
	else {
		imgp.setImage(i);
		lastfile = f;
		}
	}

	private void loadURL(String u)
	{
	try {
		Image i = Util.tk.getImage(new URL(u));
		if (i == null || !Util.waitForImage(i))
			new ErrorWindow("Failed to load image from "+u);
		else {
			imgp.setImage(i);
			lastfile = u;
			}
		}
	catch(MalformedURLException e) {
		new ErrorWindow(u+" is not a valid URL");
		}
	}
}


class ScrollImage extends Panel implements CbScrollbarCallback
{
	Image img;
	int imgw, imgh;
	int pw, ph;
	CbScrollbar vsc, hsc;
	boolean compute_scrollbars = true;

	ScrollImage(Image i)
	{
	this(i, Util.getWidth(i), Util.getHeight(i));
	}

	ScrollImage(Image i, int w, int h)
	{
	pw = w; ph = h;
	setLayout(new BorderLayout());
	add("East", vsc = new CbScrollbar(CbScrollbar.VERTICAL, this));
	add("South", hsc = new CbScrollbar(CbScrollbar.HORIZONTAL, this));
	setImage(i);
	}

	void setImage(Image i)
	{
	img = i;
	if (img != null) {
		imgw = Util.getWidth(img);
		imgh = Util.getHeight(img);
		}
	compute_scrollbars = true;
	repaint();
	}

	public void paint(Graphics g)
	{
	int w = size().width-vsc.size().width,
	    h = size().height-hsc.size().height;
	if (compute_scrollbars) {
		if (img == null) {
			hsc.setValues(0, 1, 1);
			vsc.setValues(0, 1, 1);
			}
		else {
			if (imgw < w) hsc.setValues(0, 1, 1);
			else hsc.setValues(0, w, imgw);
			if (imgh < h) vsc.setValues(0, 1, 1);
			else vsc.setValues(0, h, imgh);
			}
		compute_scrollbars = false;
		}

	g.setColor(Util.body);
	g.fillRect(0, 0, w, h);
	if (img != null) {
		if (imgw < w && imgh < h)
			g.drawImage(img, (w-imgw)/2, (h-imgh)/2, this);
		else
			g.drawImage(img, -hsc.getValue(), -vsc.getValue(),this);
		}
	else {
		g.setFont(Util.f);
		g.setColor(Util.text);
		String s = "<None>";
		g.drawString(s, (w-Util.fnm.stringWidth(s))/2,
		                (h-Util.fnm.getHeight())/2);
		}
	}

	public void update(Graphics g) { paint(g); }

	public void reshape(int nx, int ny, int nw, int nh)
	{
	super.reshape(nx, ny, nw, nh);
	compute_scrollbars = true;
	repaint();
	}

	public void moved(CbScrollbar s, int p)
	{
	repaint();
	}

	public void moving(CbScrollbar s, int p) { }

	public Dimension minimumSize()
	{
	return new Dimension(pw, ph);
	}

	public Dimension preferredSize()
	{
	return minimumSize();
	}
}
