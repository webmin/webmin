import java.awt.*;
import java.util.*;

/**A window for choosing a colour, either from a pre-set palette
 * or from a color cube
 */
class CbColorWindow extends FixedFrame implements CbButtonCallback
{
	CbColorWindowCallback callback;
	Color col;
	Vector pal;
	static Vector defpal = new Vector();
	Image palimg[] = new Image[12];
	CbButton palbut[] = new CbButton[12];
	int curpal = -1;
	CbButton ok, cancel;
	CbColorWindowCube ccube;

	static
	{
	defpal.addElement(Color.black);
	defpal.addElement(Color.blue);
	defpal.addElement(Color.cyan);
	defpal.addElement(Color.gray);
	defpal.addElement(Color.green);
	defpal.addElement(Color.darkGray);
	defpal.addElement(Color.magenta);
	defpal.addElement(Color.orange);
	defpal.addElement(Color.pink);
	defpal.addElement(Color.red);
	defpal.addElement(Color.white);
	defpal.addElement(Color.yellow);
	}

	CbColorWindow(Color c, CbColorWindowCallback cb)
	{
	col = c;
	callback = cb;

	// Setup color vector
	pal = callback.palette(this);
	if (pal == null)
		pal = defpal;
	else if (pal.size() == 0)
		for(int i=0; i<12; i++)
			pal.addElement(defpal.elementAt(i));

	// Create palette images
	for(int i=0; i<12; i++) {
		palimg[i] = Util.createImage(16, 16);
		updatePal(i);
		}

	// create UI
	setLayout(new BorderLayout());
	Panel bot = new GrayPanel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(ok = new CbButton("Ok", this));
	bot.add(cancel = new CbButton("Cancel", this));
	add("South", bot);
	Panel mid = new BorderPanel(1);
	mid.setLayout(new BorderLayout());
	Panel midbot = new GrayPanel();
	midbot.setLayout(new GridLayout(2, 6, 4, 4));
	CbButtonGroup g = new CbButtonGroup();
	for(int i=0; i<12; i++) {
		midbot.add(palbut[i] = new CbButton(palimg[i], this));
		palbut[i].setGroup(g);
		}
	for(int i=0; i<12; i++)
		if (c.equals(pal.elementAt(i))) {
			curpal = i;
			palbut[i].select();
			break;
			}
	mid.add("South", midbot);
	mid.add("North", ccube = new CbColorWindowCube(this));
	add("Center", mid);

	pack();
	show();
	setTitle("Choose Color...");
	}

	void updatePal(int i)
	{
	Graphics g = palimg[i].getGraphics();
	g.setColor((Color)pal.elementAt(i));
	g.fillRect(0, 0, 16, 16);
	if (palbut[i] != null) palbut[i].repaint();
	}

	public void click(CbButton b)
	{
	if (b == ok) {
		callback.chosen(this, col);
		super.dispose();
		}
	else if (b == cancel)
		dispose();
	else {
		for(int i=0; i<12; i++)
			if (b == palbut[i]) {
				curpal = i;
				col = (Color)pal.elementAt(i);
				ccube.red.setPosition(col.getRed());
				ccube.blue.setPosition(col.getBlue());
				ccube.green.setPosition(col.getGreen());
				ccube.swatch.setColor(col);
				}
		}
	}

	public void dispose()
	{
	super.dispose();
	callback.chosen(this, null);
	}

	public boolean isResizable() { return false; }
}

/**Displays 3 sliders, for red green and blue plus a block to show the
 * current color
 */
class CbColorWindowCube extends BorderPanel implements CbSliderCallback
{
	CbColorWindow parent;
	CbSlider red, green, blue;
	CbColorWindowSwatch swatch;

	CbColorWindowCube(CbColorWindow p)
	{
	super(1, Util.body, Util.body);
	parent = p;
	setLayout(new BorderLayout());
	Panel sl = new GrayPanel();
	sl.setLayout(new GridLayout(3, 1));
	sl.add(red = new CbSlider(0, 0, 255, p.col.getRed(), this));
	sl.add(green = new CbSlider(0, 0, 255, p.col.getBlue(), this));
	sl.add(blue = new CbSlider(0, 0, 255, p.col.getGreen(), this));
	add("Center", sl);
	add("East", swatch = new CbColorWindowSwatch(p.col));
	}

	public void moved(CbSlider s, int p)
	{
	moving(s, p);
	}

	public void moving(CbSlider s, int p)
	{
	parent.col = new Color(red.getPosition(), green.getPosition(),
	                       blue.getPosition());
	swatch.setColor(parent.col);
	if (parent.curpal != -1) {
		parent.pal.setElementAt(parent.col, parent.curpal);
		parent.updatePal(parent.curpal);
		}
	}
}


interface CbColorWindowCallback
{
	/**This method will be called when the user chooses a colour. If
	 * the user cancels the dialog, then this method will also be chosen
	 * but with null for the color.
	 */
	public void chosen(CbColorWindow w, Color c);

	/**The chooser keeps a palette of colors that the user can modify,
	 * stored in a vector. The callback class should provide this vector
	 * so as to maintain the palette between color window calls.
	 * If an empty vector is returned, it will be filled with the default
	 * color table (which can be then modified).
	 * If null is returned, the chooser will use it's own internal
	 * vector.
	 */
	public Vector palette(CbColorWindow w);
}


class CbColorWindowSwatch extends BorderPanel
{
	Color col = Color.black;
	String txt;

	CbColorWindowSwatch(Color c)
	{
	super(1);
	setColor(c);
	}

	void setColor(Color c)
	{
	col = c;
	txt = col.getRed()+","+col.getGreen()+","+col.getBlue();
	repaint();
	}

	public void paint(Graphics g)
	{
	super.paint(g);
	g.setColor(col);
	g.fillRect(1, 1, size().width-2, size().height-2);
	g.setColor(Color.white);
	g.setXORMode(Color.black);
	g.setFont(Util.f);
	g.drawString(txt, 3, Util.fnm.getHeight()+1);
	g.setPaintMode();
	}

	public void upate(Graphics g) { paint(g); }

	public Dimension preferredSize()
	{
	return new Dimension(60, 60);
	}

	public Dimension minimumSize()
	{
	return preferredSize();
	}
}

