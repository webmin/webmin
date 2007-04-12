import java.awt.*;
import java.awt.image.*;

class Util
{
	static Frame fr;
	static Graphics g;
	static Font f;
	static FontMetrics fnm;
	static Toolkit tk;

	static Color light_edge = Color.white;
	static Color dark_edge = Color.black;
	static Color body = Color.lightGray;
	static Color body_hi = new Color(210, 210, 210);
	static Color light_edge_hi = Color.white;
	static Color dark_edge_hi = Color.darkGray;
	static Color dark_bg = new Color(150, 150, 150);
	static Color text = Color.black;
	static Color light_bg = Color.white;

	static
	{
	fr = new Frame();
	fr.addNotify();
	g = fr.getGraphics();
	setFont(new Font("TimesRoman", Font.PLAIN, 8));
	tk = Toolkit.getDefaultToolkit();
	}

	static boolean waitForImage(Image i)
	{
	MediaTracker mt = new MediaTracker(fr);
	mt.addImage(i, 0);
	try { mt.waitForAll(); } catch(Exception e) { return false; }
	return !mt.isErrorAny();
	}

	static boolean waitForImage(Image i, int w, int h)
	{
	MediaTracker mt = new MediaTracker(fr);
	mt.addImage(i, w, h, 0);
	try { mt.waitForAll(); } catch(Exception e) { return false; }
	return !mt.isErrorAny();
	}

	static int getWidth(Image i)
	{
	waitForImage(i);
	return i.getWidth(fr);
	}

	static int getHeight(Image i)
	{
	waitForImage(i);
	return i.getHeight(fr);
	}

	static Image createImage(int w, int h)
	{
	return fr.createImage(w, h);
	}

	static Image createImage(ImageProducer p)
	{
	return fr.createImage(p);
	}

	static Object createObject(String name)
	{
	try {
		Class c = Class.forName(name);
		return c.newInstance();
		}
	catch(Exception e) {
		System.err.println("Failed to create object "+name+" : "+
				   e.getClass().getName());
		System.exit(1);
		}
	return null;
	}

	/**Create a new instance of some object
	 */
	static Object createObject(Object o)
	{
	try { return o.getClass().newInstance(); }
	catch(Exception e) {
		System.err.println("Failed to reproduce object "+o+" : "+
	                         e.getClass().getName());
		System.exit(1);
		}
	return null;
	}


	static void dottedRect(Graphics g, int x1, int y1,
	                       int x2, int y2, int s)
	{
	int i, s2 = s*2, t;
	if (x2 < x1) { t = x1; x1 = x2; x2 = t; }
	if (y2 < y1) { t = y1; y1 = y2; y2 = t; }
	for(i=x1; i<=x2; i+=s2)
		g.drawLine(i, y1, i+s > x2 ? x2 : i+s, y1);
	for(i=y1; i<=y2; i+=s2)
		g.drawLine(x2, i, x2, i+s > y2 ? y2 : i+s);
	for(i=x2; i>=x1; i-=s2)
		g.drawLine(i, y2, i-s < x1 ? x1 : i-s, y2);
	for(i=y2; i>=y1; i-=s2)
		g.drawLine(x1, i, x1, i-s < y1 ? y1 : i-s);
	}

	static void recursiveLayout(Container c)
	{
	c.layout();
	for(int i=0; i<c.countComponents(); i++) {
		Component cc = c.getComponent(i);
		if (cc instanceof Container)
			recursiveLayout((Container)cc);
		}
	}

	static void recursiveBackground(Component c, Color b)
	{
	if (c instanceof TextField || c instanceof Choice ||
	    c instanceof TextArea)
		return;		// leave these alone
	c.setBackground(b);
	if (c instanceof Container) {
		Container cn = (Container)c;
		for(int i=0; i<cn.countComponents(); i++)
			recursiveBackground(cn.getComponent(i), b);
		}
	}

	static void recursiveBody(Component c)
	{
	recursiveBackground(c, Util.body);
	}

	static void setFont(Font nf)
	{
	f = nf;
	g.setFont(f);
	fnm = g.getFontMetrics();
	}
}

