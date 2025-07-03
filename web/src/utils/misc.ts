export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

/**
 * Convert hex color to RGB values
 * @param hex - Hex color string (e.g., "#FF0000")
 * @returns RGB string (e.g., "255, 0, 0") or default indigo if invalid
 */
export const hexToRgb = (hex: string): string => {
  // Handle transparent colors
  if (hex === "#00000000" || hex === "transparent") {
    return "43, 196, 47"; // Default to green-500
  }

  // Remove # if present
  const cleanHex = hex.replace('#', '');
  
  // Handle 3-digit hex codes
  if (cleanHex.length === 3) {
    const expanded = cleanHex.split('').map(char => char + char).join('');
    return hexToRgb('#' + expanded);
  }
  
  // Handle 6-digit hex codes
  if (cleanHex.length === 6) {
    const r = parseInt(cleanHex.substr(0, 2), 16);
    const g = parseInt(cleanHex.substr(2, 2), 16);
    const b = parseInt(cleanHex.substr(4, 2), 16);
    
    if (isNaN(r) || isNaN(g) || isNaN(b)) {
      return "43, 196, 47"; // Default to green-500
    }
    
    return `${r}, ${g}, ${b}`;
  }
  
  // Return default if invalid format
  return "43, 196, 47"; // Default to green-500
};

/**
 * Generate a secondary color by adjusting hue
 * @param rgbString - RGB string (e.g., "255, 0, 0")
 * @returns Modified RGB string for secondary color
 */
export const generateSecondaryColor = (rgbString: string): string => {
  const [r, g, b] = rgbString.split(', ').map(num => parseInt(num));
  
  // Convert RGB to HSL
  const rNorm = r / 255;
  const gNorm = g / 255;
  const bNorm = b / 255;
  
  const max = Math.max(rNorm, gNorm, bNorm);
  const min = Math.min(rNorm, gNorm, bNorm);
  const diff = max - min;
  
  let h = 0;
  if (diff !== 0) {
    if (max === rNorm) {
      h = ((gNorm - bNorm) / diff + 6) % 6;
    } else if (max === gNorm) {
      h = (bNorm - rNorm) / diff + 2;
    } else {
      h = (rNorm - gNorm) / diff + 4;
    }
  }
  h /= 6;
  
  const l = (max + min) / 2;
  const s = diff === 0 ? 0 : diff / (1 - Math.abs(2 * l - 1));
  
  // Shift hue by 30 degrees for secondary color
  h = (h + 30/360) % 1;
  
  // Convert back to RGB
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs((h * 6) % 2 - 1));
  const m = l - c/2;
  
  let rNew, gNew, bNew;
  if (h < 1/6) {
    [rNew, gNew, bNew] = [c, x, 0];
  } else if (h < 2/6) {
    [rNew, gNew, bNew] = [x, c, 0];
  } else if (h < 3/6) {
    [rNew, gNew, bNew] = [0, c, x];
  } else if (h < 4/6) {
    [rNew, gNew, bNew] = [0, x, c];
  } else if (h < 5/6) {
    [rNew, gNew, bNew] = [x, 0, c];
  } else {
    [rNew, gNew, bNew] = [c, 0, x];
  }
  
  const finalR = Math.round((rNew + m) * 255);
  const finalG = Math.round((gNew + m) * 255);
  const finalB = Math.round((bNew + m) * 255);
  
  return `${finalR}, ${finalG}, ${finalB}`;
};

/**
 * Apply color configuration to CSS custom properties
 * @param primaryColor - Primary color hex string
 */
export const applyColorConfig = (primaryColor: string): void => {
  const primaryRgb = hexToRgb(primaryColor);
  const secondaryRgb = generateSecondaryColor(primaryRgb);
  
  const root = document.documentElement;
  root.style.setProperty('--primary-color', primaryRgb);
  root.style.setProperty('--secondary-color', secondaryRgb);
};
