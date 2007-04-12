import java.awt.*;
import java.lang.Math;

/**
 * A ToolbarLayout arranges components in a left-to-right flow, much 
 * like the FlowLayout which is supplied with the JDK.  However, it
 * fixes the problem with the FlowLayout that occurs when a FlowLayout
 * is for a North aligned component of a BorderLayout--namely, that
 * if the window is shrunk so that some of the components within the
 * FlowLayout wrap to the next line the component does not grow in
 * height to support this wrapping.  This bug was caused by the library
 * designers using the preferred size in recalculating, not the size
 * which is determined by the window width.  As such, the flow layout
 * would always want to be the height of one row.
 *
 * A ToolbarLayout lets each component assume its natural (preferred) size.
 *
 * NOTE: This class was initially a subclass of FlowLayout, but we
 *       encountered problems using that approach.
 *
 * @version 	0.10, 1999-04-27
 * @author 	Peter Armstrong
 * @author 	Tony Johnson
 */
public class ToolbarLayout implements LayoutManager, java.io.Serializable {

    /**
     * This value indicates that each row of components
     * should be left-justified. 
     */
    public static final int LEFT 	= 0;

    /**
     * This value indicates that each row of components
     * should be centered. 
     */
    public static final int CENTER 	= 1;

    /**
     * This value indicates that each row of components
     * should be right-justified. 
     */
    public static final int RIGHT 	= 2;

    int align;
    int hgap;
    int vgap;


    /**
     * Constructs a new ToolbarLayout with a left alignment and a
     * default 5-unit horizontal and vertical gap.
     */
    public ToolbarLayout() {
		this(LEFT, 5, 5);
    }

    /**
     * Constructs a new ToolbarLayout with the specified alignment and a
     * default 5-unit horizontal and vertical gap.
     * The value of the alignment argument must be one of 
     * <code>ToolbarLayout.LEFT</code>, <code>ToolbarLayout.RIGHT</code>, 
     * or <code>ToolbarLayout.CENTER</code>.
     * @param align the alignment value
     */
    public ToolbarLayout(int align) {
		this(align, 5, 5);
    }

    /**
     * Creates a new ToolbarLayout with the indicated alignment 
     * and the indicated horizontal and vertical gaps. 
     * <p>
     * The value of the alignment argument must be one of 
     * <code>ToolbarLayout.LEFT</code>, <code>ToolbarLayout.RIGHT</code>, 
     * or <code>ToolbarLayout.CENTER</code>.
     * @param      align   the alignment value.
     * @param      hgap    the horizontal gap between components.
     * @param      vgap    the vertical gap between components.
     */
    public ToolbarLayout(int align, int hgap, int vgap) {
		this.align = align;
		this.hgap = hgap;
		this.vgap = vgap;
    }

    /**
     * Gets the alignment for this layout.
     * Possible values are <code>ToolbarLayout.LEFT</code>,  
     * <code>ToolbarLayout.RIGHT</code>, or <code>ToolbarLayout.CENTER</code>.  
     * @return     the alignment value for this layout.
     * @see        ToolbarLayout#setAlignment
     */
    public int getAlignment() {
		return align;
    }
    
    /**
     * Sets the alignment for this layout.
     * Possible values are <code>ToolbarLayout.LEFT</code>,  
     * <code>ToolbarLayout.RIGHT</code>, and <code>ToolbarLayout.CENTER</code>.  
     * @param      align the alignment value.
     * @see        ToolbarLayout#getAlignment
     */
    public void setAlignment(int align) {
		this.align = align;
    }

    /**
     * Gets the horizontal gap between components.
     * @return     the horizontal gap between components.
     * @see        ToolbarLayout#setHgap
     */
    public int getHgap() {
		return hgap;
    }
    
    /**
     * Sets the horizontal gap between components.
     * @param hgap the horizontal gap between components
     * @see        ToolbarLayout#getHgap
     */
    public void setHgap(int hgap) {
		this.hgap = hgap;
    }
    
    /**
     * Gets the vertical gap between components.
     * @return     the vertical gap between components.
     * @see        ToolbarLayout#setVgap
     */
    public int getVgap() {
		return vgap;
    }
    
    /**
     * Sets the vertical gap between components.
     * @param vgap the vertical gap between components
     * @see        ToolbarLayout#getVgap
     */
    public void setVgap(int vgap) {
		this.vgap = vgap;
    }

    /**
     * Adds the specified component to the layout.  Sets the orientation to be horizontal.
     * @param name the name of the component
     * @param comp the component to be added
     */
    public void addLayoutComponent(String name, Component comp) {
    }

    /**
     * Removes the specified component from the layout. Not used by
     * this class.  
     * @param comp the component to remove
     * @see       java.awt.Container#removeAll
     */
    public void removeLayoutComponent(Component comp) {
    }

    /**
     * Returns the preferred dimensions for this layout given the components
     * in the specified target container.  This method is the difference
     * between ToolbarLayout and FlowLayout.
     * @param target the component which needs to be laid out
     * @return    the preferred dimensions to lay out the 
     *                    subcomponents of the specified container.
     * @see Container
     * @see #minimumLayoutSize
     * @see	java.awt.Container#getPreferredSize
     */
    public Dimension preferredLayoutSize(Container target) {
		synchronized (target.getTreeLock()) {
			Dimension dim = new Dimension(0, 0);
			int nmembers = target.getComponentCount();

			Insets insets = target.getInsets();

			int numRows		= 1;							//the number of rows
			int rowSumWidth = insets.left + insets.right;	//the width of the row so far
			int rowMaxWidth = target.getSize().width;		//the width that the ToolbarLayout is in
			int rowHeight	= 0;							//the height of each row
			int numOnRow	= 0;							//the number of components on the row
			
			for (int i = 0 ; i < nmembers ; i++) {
			    Component m = target.getComponent(i);
			    if (m.isVisible()) {
					Dimension d = m.getPreferredSize();
					rowHeight = Math.max(rowHeight, d.height);	//make each row the height of the biggest component of all
					if (i > 0) {
						rowSumWidth += hgap;//add on the pre-spacing if this is not the first component
					}
					rowSumWidth += d.width;	//add the width of the component
					
					//if it overflowed and if there are components already on this row then bump this component to next row
					if ((rowSumWidth + hgap) > rowMaxWidth) {
						if (numOnRow > 0) {
							numRows++;
							rowSumWidth = insets.left + insets.right + d.width;
							numOnRow = 0;//reset the number of components on the next row (we ++ no matter what later)
						}
					}
					numOnRow++;//add this component to the count of the number on the row
		    	}
			}
			dim.width = rowMaxWidth;
			dim.height = insets.top + insets.bottom + numRows*rowHeight + vgap*(numRows + 1);
			return dim;
		}
    }
     
    /**
     * Returns the minimum dimensions needed to layout the components
     * contained in the specified target container.
     * @param target the component which needs to be laid out 
     * @return    the minimum dimensions to lay out the 
     *                    subcomponents of the specified container.
     * @see #preferredLayoutSize
     * @see       java.awt.Container
     * @see       java.awt.Container#doLayout
     */
    public Dimension minimumLayoutSize(Container target) {
		synchronized (target.getTreeLock()) {
			Dimension dim = new Dimension(0, 0);
			int nmembers = target.getComponentCount();

			for (int i = 0 ; i < nmembers ; i++) {
			    Component m = target.getComponent(i);
			    if (m.isVisible()) {
					Dimension d = m.getMinimumSize();
					dim.height = Math.max(dim.height, d.height);
					if (i > 0) {
					    dim.width += hgap;
					}
					dim.width += d.width;
			    }
			}
			Insets insets = target.getInsets();
			dim.width += insets.left + insets.right + hgap*2;
			dim.height += insets.top + insets.bottom + vgap*2;
			return dim;
		}
    }

    /** 
     * Centers the elements in the specified row, if there is any slack.
     * @param target the component which needs to be moved
     * @param x the x coordinate
     * @param y the y coordinate
     * @param width the width dimensions
     * @param height the height dimensions
     * @param rowStart the beginning of the row
     * @param rowEnd the the ending of the row
     */
    private void moveComponents(Container target, int x, int y, int width, int height, int rowStart, int rowEnd) {
		synchronized (target.getTreeLock()) {
			switch (align) {
			case LEFT:
			    break;
			case CENTER:
			    x += width / 2;
			    break;
			case RIGHT:
			    x += width;
			    break;
			}
			for (int i = rowStart ; i < rowEnd ; i++) {
			    Component m = target.getComponent(i);
			    if (m.isVisible()) {
					m.setLocation(x, y + (height - m.size().height) / 2);
					x += hgap + m.size().width;
			    }
			}
		}
    }

    /**
     * Lays out the container. This method lets each component take 
     * its preferred size by reshaping the components in the 
     * target container in order to satisfy the constraints of
     * this <code>ToolbarLayout</code> object. 
     * @param target the specified component being laid out.
     * @see Container
     * @see       java.awt.Container#doLayout
     */
    public void layoutContainer(Container target) {
		synchronized (target.getTreeLock()) {
			Insets insets = target.getInsets();
			int maxwidth = target.size().width - (insets.left + insets.right + hgap*2);
			int nmembers = target.getComponentCount();
			int x = 0, y = insets.top + vgap;
			int rowh = 0, start = 0;

			for (int i = 0 ; i < nmembers ; i++) {
				Component m = target.getComponent(i);
			    if (m.isVisible()) {
					Dimension d = m.getPreferredSize();
					m.setSize(d.width, d.height);
					if ((x == 0) || ((x + d.width) <= maxwidth)) {
					    if (x > 0) {
							x += hgap;
					    }
					    x += d.width;
					    rowh = Math.max(rowh, d.height);
					} else {
					    moveComponents(target, insets.left + hgap, y, maxwidth - x, rowh, start, i);
					    x = d.width;
					    y += vgap + rowh;
					    rowh = d.height;
					    start = i;
					}
			    }
			}
			moveComponents(target, insets.left + hgap, y, maxwidth - x, rowh, start, nmembers);
		}
    }
    
    /**
     * Returns a string representation of this <code>ToolbarLayout</code>
     * object and its values.
     * @return     a string representation of this layout.
     */
    public String toString() {
		String str = "";
		switch (align) {
			case LEFT:    str = ",align=left"; break;
			case CENTER:  str = ",align=center"; break;
			case RIGHT:   str = ",align=right"; break;
		}
		return getClass().getName() + "[hgap=" + hgap + ",vgap=" + vgap + str + "]";
    }
}
