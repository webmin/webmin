// CbScrollbar.java
// A drop-in replacement for the AWT scrollbar class, with callbacks
// and a nicer look. This scrollbar is typically used to display some
// fraction of a list of items, with values ranging from min to max.
// The lvisible parameter determines how many of the list are lvisible
// at any one time. The value of the scrollbar ranges from min to
// max-lvisible+1 (the highest position in the list to start displaying)
import java.awt.*;

public class CbScrollbar extends Panel
{
	static final int VERTICAL = 0;
	static final int HORIZONTAL = 1;
	CbScrollbarCallback callback;		// who to call back to
	boolean inside, indent;
	int orient;			// horizontal or vertical?
	int value;			// position
	int lvisible;			// the number of lines lvisible
	int num;			// total number of lines
	int lineinc = 1;		// how much the arrow buttons move by
	Color lc1 = Util.light_edge, lc2 = Util.body, lc3 = Util.dark_edge;
	Color hc1 = Util.light_edge_hi, hc2 = Util.body_hi, hc3 = Util.dark_edge_hi;
	Color bc = Util.dark_bg;
	int y1, y2, x1, x2, drag;

	CbScrollbarArrow arrow1, arrow2;

	CbScrollbar(int o, CbScrollbarCallback cb)
	{
	this(o, 0, 1, 1, cb);
	}

	/**Create a new scrollbar
	 */
	CbScrollbar(int o, int v, int vis, int n, CbScrollbarCallback cb)
	{
	setValues(v, vis, n);
	orient = o;
	callback = cb;
	setLayout(null);
	if (orient == VERTICAL) {
		add(arrow1 = new CbScrollbarArrow(this, 0));
		add(arrow2 = new CbScrollbarArrow(this, 1));
		}
	else {
		add(arrow1 = new CbScrollbarArrow(this, 2));
		add(arrow2 = new CbScrollbarArrow(this, 3));
		}
	}

	/**Set the current scrollbar parameters
	 * @param v		Current position
	 * @param vis		Number of lines lvisible
	 * @param n		Total number of lines
	 */
	public void setValues(int v, int vis, int n)
	{
	value = v;
	lvisible = vis;
	num = n;
	if (lvisible > num) lvisible = num;
	checkValue();
	repaint();
	}

	public int getValue() { return value; }

	public void setValue(int v)
	{
	value = v;
	checkValue();
	repaint();
	}

	private void checkValue()
	{
	if (value < 0) value = 0;
	else if (value > num-lvisible) value = num-lvisible;
	}

	public void paint(Graphics g)
	{
	if (num == 0) return;
	int w = size().width, h = size().height;
	boolean ins = inside && !(arrow1.inside || arrow2.inside);
	Color c1 = ins ? hc1 : lc1, c2 = ins ? hc2 : lc2,
	      c3 = ins ? hc3 : lc3;
	g.setColor(bc);
	g.fillRect(0, 0, w, h);
	g.setColor(c3);
	g.drawLine(0, 0, w-1, 0); g.drawLine(0, 0, 0, h-1);
	g.setColor(c1);
	g.drawLine(w-1, h-1, w-1, 0); g.drawLine(w-1, h-1, 0, h-1);

	if (orient == VERTICAL) {
		int va = h-w*2;
		y1 = w+va*value/num;
		y2 = w+va*(value+lvisible)/num-1;
		g.setColor(c2);
		g.fillRect(1, y1, w-2, y2-y1);
		g.setColor(indent ? c3 : c1);
		g.drawLine(1, y1, w-2, y1);
		g.drawLine(1, y1, 1, y2-1);
		g.setColor(indent ? c1 : c3);
		g.drawLine(w-2, y2-1, w-2, y1);
		g.drawLine(w-2, y2-1, 1, y2-1);
		if (ins) {
			g.drawLine(w-3, y2-2, w-3, y1+1);
			g.drawLine(w-3, y2-2, 2, y2-2);
			}
		}
	else if (orient == HORIZONTAL) {
		int va = w-h*2;
		x1 = h+va*value/num;
		x2 = h+va*(value+lvisible)/num-1;
		g.setColor(c2);
		g.fillRect(x1, 1, x2-x1, h-2);
		g.setColor(indent ? c3 : c1);
		g.drawLine(x1, 1, x1, h-2);
		g.drawLine(x1, 1, x2-1, 1);
		g.setColor(indent ? c1 : c3);
		g.drawLine(x2-1, h-2, x1, h-2);
		g.drawLine(x2-1, h-2, x2-1, 1);
		if (ins) {
			g.drawLine(x2-2, h-3, x1+1, h-3);
			g.drawLine(x2-2, h-3, x2-2, 2);
			}
		}
	}

	/**Called by arrows to move the slider
	 */
	void arrowClick(int d)
	{
	int oldvalue = value;
	value += d;
	checkValue();
	if (value != oldvalue) {
		callback.moved(this, value);
		repaint();
		}
	}

	public void reshape(int nx, int ny, int nw, int nh)
	{
	super.reshape(nx, ny, nw, nh);
	if (orient == VERTICAL) {
		arrow1.reshape(1, 1, nw-2, nw-1);
		arrow2.reshape(1, nh-nw-1, nw-2, nw-1);
		}
	else {
		arrow1.reshape(1, 1, nh-1, nh-2);
		arrow2.reshape(nw-nh-1, 1, nh-1, nh-2);
		}
	repaint();
	}

	public Dimension preferredSize()
	{
	return orient==VERTICAL ? new Dimension(16, 100)
				: new Dimension(100, 16);
	}

	public Dimension minimumSize()
	{
	return preferredSize();
	}

	public boolean mouseDown(Event e, int mx, int my)
	{
	if (orient == VERTICAL) {
		// move up/down one page, or start dragging
		if (my < y1) arrowClick(-lvisible);
		else if (my > y2) arrowClick(lvisible);
		else {
			indent = true;
			drag = my-y1;
			repaint();
			}
		}
	else {
		// move left/right one page, or start dragging
		if (mx < x1) arrowClick(-lvisible);
		else if (mx > x2) arrowClick(lvisible);
		else {
			indent = true;
			drag = mx-x1;
			repaint();
			}
		}
	return true;
	}

	public boolean mouseDrag(Event e, int mx, int my)
	{
	if (indent) {
		int w = size().width, h = size().height;
		int oldvalue = value;
		if (orient == VERTICAL) {
			int va = h-w*2, ny = my-drag-w;
			value = ny*num/va;
			}
		else {
			int va = w-h*2, nx = mx-drag-h;
			value = nx*num/va;
			}
		checkValue();
		if (value != oldvalue) {
			callback.moving(this, value);
			repaint();
			}
		}
	return indent;
	}

	public boolean mouseUp(Event e, int mx, int my)
	{
	if (indent) {
		indent = false;
		repaint();
		callback.moved(this, value);
		return true;
		}
	return false;
	}

/*
	public boolean mouseEnter(Event e, int mx, int my)
	{
	inside = true;
	repaint();
	return true;
	}

	public boolean mouseExit(Event e, int mx, int my)
	{
	inside = false;
	repaint();
	return true;
	}
*/
}

class CbScrollbarArrow extends Canvas implements Runnable
{
	int mode;
	CbScrollbar scrollbar;
	boolean inside, indent;
	Thread th;

	CbScrollbarArrow(CbScrollbar p, int m)
	{
	scrollbar = p;
	mode = m;
	}

	public void paint(Graphics g)
	{
	int w = size().width, h = size().height;
	Color c1 = inside ? scrollbar.hc1 : scrollbar.lc1,
	      c2 = inside ? scrollbar.hc2 : scrollbar.lc2,
	      c3 = inside ? scrollbar.hc3 : scrollbar.lc3;
	g.setColor(scrollbar.bc);
	g.fillRect(0, 0, w, h);
	int xp[] = new int[3], yp[] = new int[3];
	// blank, dark, light
	if (mode == 0) {
		// up arrow
		xp[0] = w/2; xp[1] = w-1; xp[2] = 0;
		yp[0] = 0;   yp[1] = h-1; yp[2] = h-1;
		}
	else if (mode == 1) {
		// down arrow
		xp[0] = 0;   xp[1] = w/2; xp[2] = w-1;
		yp[0] = 0;   yp[1] = h-1; yp[2] = 0;
		}
	else if (mode == 2) {
		// left arrow
		xp[0] = 0;   xp[1] = w-1; xp[2] = w-1; 
		yp[0] = h/2; yp[1] = h-1; yp[2] = 0;
		}
	else if (mode == 3) {
		// right arrow
		xp[0] = 0;   xp[1] = w-1; xp[2] = 0;
		yp[0] = 0;   yp[1] = h/2; yp[2] = h-1;
		}
	g.setColor(c2);
	g.fillPolygon(xp, yp, 3);
	g.setColor(indent ? c1 : c3);
	g.drawLine(xp[1], yp[1], xp[2], yp[2]);
	g.setColor(indent ? c3 : c1);
	g.drawLine(xp[0], yp[0], xp[2], yp[2]);
	}

	public boolean mouseDown(Event e, int mx, int my)
	{
	indent = true;
	repaint();
	(th = new Thread(this)).start();
	return true;
	}

	public boolean mouseUp(Event e, int mx, int my)
	{
	indent = false;
	repaint();
	if (th != null) th.stop();
	return true;
	}

	/**Thread for doing repeated scrolling
	 */
	public void run()
	{
	int stime = 500;
	while(true) {
		scrollbar.arrowClick(mode%2 == 0 ? -1 : 1);
		try { Thread.sleep(stime); } catch(Exception e) { }
		stime = 100;
		}
	}
}


// CbScrollbarCallback
// Methods for reporting the movement of the scrollbar to another object
interface CbScrollbarCallback
{
	/**Called when the scrollbar stops moving. This happens when an
	 * arrow is clicked, the scrollbar is moved by a page, or the user
	 * lets go of the scrollbar after dragging it.
	 * @param sb	The scrollar that has been moved
	 * @param v	The new value
	 */
	void moved(CbScrollbar sb, int v);

	/**Called upon every pixel movement of the scrollbar when it is
	 * being dragged, but NOT when moved() is called.
	 * @param sb	The scrollar that has been moved
	 * @param v	The new value
	 */
	void moving(CbScrollbar sb, int v);
}


