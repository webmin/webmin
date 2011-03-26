import java.awt.*;
import java.util.*;

public class CbButton extends Canvas
{
	public static final int LEFT = 0;
	public static final int RIGHT = 1;
	public static final int ABOVE = 2;
	public static final int BELOW = 3;

	Image image;
	String string;
	CbButtonCallback callback;
	int imode;
	int iwidth, iheight, pwidth, pheight, twidth, theight;
	boolean inside, indent;

	CbButtonGroup group;
	boolean selected;

	Color lc1 = Util.light_edge, lc2 = Util.body, lc3 = Util.dark_edge;
	Color hc1 = Util.light_edge_hi, hc2 = Util.body_hi, hc3 = Util.dark_edge_hi;

	public CbButton(Image i, CbButtonCallback cb)
	{
	this(i, null, LEFT, cb);
	}

	public CbButton(String s, CbButtonCallback cb)
	{
	this(null, s, LEFT, cb);
	}

	public CbButton(Image i, String s, int im, CbButtonCallback cb)
	{
	image = i;
	string = s;
	imode = im;
	callback = cb;
	if (image != null) {
		iwidth = Util.getWidth(image);
		iheight = Util.getHeight(image);
		}
	if (string != null) {
		twidth = Util.fnm.stringWidth(string);
		theight = Util.fnm.getHeight();
		}
	if (image != null && string != null) {
		switch(imode) {
		case LEFT:
		case RIGHT:
			pwidth = iwidth + twidth + 6;
			pheight = Math.max(iheight , theight) + 4;
			break;
		case ABOVE:
		case BELOW:
			pwidth = Math.max(iwidth, twidth) + 4;
			pheight = iheight + theight + 6;
			break;
			}
		}
	else if (image != null) {
		pwidth = iwidth + 4;
		pheight = iheight + 4;
		}
	else if (string != null) {
		pwidth = twidth + 8;
		pheight = theight + 8;
		}
	}

	/**Make this button part of a mutual-exclusion group. Only one such
	 * button can be indented at a time
	 */
	public void setGroup(CbButtonGroup g)
	{
	group = g;
	group.add(this);
	}

	/**Make this button the selected one in it's group
	 */
	public void select()
	{
	if (group != null)
		group.select(this);
	}

	/**Display the given string
	 */
	public void setText(String s)
	{
	string = s;
	image = null;
	twidth = Util.fnm.stringWidth(string);
	theight = Util.fnm.getHeight();
	repaint();
	}

	/**Display the given image
	 */
	public void setImage(Image i)
	{
	string = null;
	image = i;
	iwidth = Util.getWidth(image);
	iheight = Util.getHeight(image);
	repaint();
	}

	/**Display the given image and text, with the given alignment mode
	 */
	public void setImageText(Image i, String s, int m)
	{
	image = i;
	string = s;
	imode = m;
	twidth = Util.fnm.stringWidth(string);
	theight = Util.fnm.getHeight();
	iwidth = Util.getWidth(image);
	iheight = Util.getHeight(image);
	repaint();
	}

	public void paint(Graphics g)
	{
	Color c1 = inside ? hc1 : lc1,
	      c2 = inside ? hc2 : lc2,
	      c3 = inside ? hc3 : lc3;
	int w = size().width, h = size().height;
	Color hi = indent||selected ? c3 : c1,
	      lo = indent||selected ? c1 : c3;
	g.setColor(c2);
	g.fillRect(0, 0, w-1, h-1);
	g.setColor(hi);
	g.drawLine(0, 0, w-2, 0);
	g.drawLine(0, 0, 0, h-2);
	g.setColor(lo);
	g.drawLine(w-1, h-1, w-1, 1);
	g.drawLine(w-1, h-1, 1, h-1);
	if (inside) {
		/* g.setColor(hi);
		g.drawLine(1, 1, w-3, 1);
		g.drawLine(1, 1, 1, h-3); */
		g.setColor(lo);
		g.drawLine(w-2, h-2, w-2, 2);
		g.drawLine(w-2, h-2, 2, h-2);
		}

	g.setColor(c3);
	g.setFont(Util.f);
	if (image != null && string != null) {
		if (imode == LEFT) {
			Dimension is = imgSize(w-twidth-6, h-4);
			g.drawImage(image, (w - is.width - twidth - 2)/2,
				    (h-is.height)/2, is.width, is.height, this);
			g.drawString(string,
				     (w - is.width - twidth - 2)/2 +is.width +2,
				     (h + theight - Util.fnm.getDescent())/2);
			}
		else if (imode == RIGHT) {
			}
		else if (imode == ABOVE) {
			//Dimension is = imgSize(w-4, h-theight-6);
			g.drawImage(image, (w - iwidth)/2, 
				    (h - iheight - theight - 2)/2,
				    iwidth, iheight, this);
			g.drawString(string, (w - twidth)/2, iheight+Util.fnm.getHeight()+2);
			}
		else if (imode == BELOW) {
			}
		}
	else if (image != null) {
		Dimension is = imgSize(w-4, h-4);
		g.drawImage(image, (w - is.width)/2, (h-is.height)/2,
			    is.width, is.height, this);
		}
	else if (string != null) {
		g.drawString(string, (w - twidth)/2,
		                     (h+theight-Util.fnm.getDescent())/2);
		}
	}

	public void update(Graphics g) { paint(g); }

	public boolean mouseEnter(Event e, int x, int y)
	{
	inside = true;
	repaint();
	return true;
	}

	public boolean mouseExit(Event e, int x, int y)
	{
	inside = false;
	repaint();
	return true;
	}

	public boolean mouseDown(Event e, int x, int y)
	{
	indent = true;
	repaint();
	return true;
	}

	public boolean mouseUp(Event e, int x, int y)
	{
	if (x >= 0 && y >= 0 && x < size().width && y < size().height) {
		if (callback != null)
			callback.click(this);
		select();
		}
	indent = false;
	repaint();
	return true;
	}

	public Dimension preferredSize()
	{
	return new Dimension(pwidth, pheight);
	}

	public Dimension minimumSize()
	{
	return preferredSize();
	}

	private Dimension imgSize(int mw, int mh)
	{
	float ws = (float)mw/(float)iwidth,
	      hs = (float)mh/(float)iheight;
	float s = ws < hs ? ws : hs;
	if (s > 1) s = 1;
	return new Dimension((int)(iwidth*s), (int)(iheight*s));
	}
}


interface CbButtonCallback
{
	void click(CbButton b);
}


class CbButtonGroup
{
	Vector buttons = new Vector();

	void add(CbButton b)
	{
	buttons.addElement(b);
	}

	void select(CbButton b)
	{
	for(int i=0; i<buttons.size(); i++) {
		CbButton but = (CbButton)buttons.elementAt(i);
		but.selected = (b == but);
		but.repaint();
		}
	}
}

