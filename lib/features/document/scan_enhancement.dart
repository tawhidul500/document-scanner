import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Estimate the paper illumination at low resolution, then correct it smoothly.
/// Local maxima keep dark text out of the lighting estimate. Color ratios are
/// retained rather than converting IDs, stamps and highlighted notes to B&W.
img.Image enhanceScan(img.Image source) {
  final tiny = img.copyResize(source, width: 64,
    height: math.max(8, (source.height * 64 / source.width).round()));
  final w = tiny.width, h = tiny.height;
  final light = List<double>.filled(w*h, 0);
  for (var y=0; y<h; y++) {
    for (var x=0; x<w; x++) {
      var brightest = 0.0;
      for (var dy=-3; dy<=3; dy++) {
        for (var dx=-3; dx<=3; dx++) {
          final p=tiny.getPixel((x+dx).clamp(0,w-1).toInt(), (y+dy).clamp(0,h-1).toInt());
          brightest=math.max(brightest, (p.r*299+p.g*587+p.b*114)/1000);
        }
      }
      light[y*w+x]=brightest;
    }
  }
  final smooth=List<double>.filled(w*h, 0);
  for (var y=0; y<h; y++) {
    for (var x=0; x<w; x++) {
      var total=0.0, count=0;
      for (var dy=-3; dy<=3; dy++) {
        for (var dx=-3; dx<=3; dx++) {
          total+=light[(y+dy).clamp(0,h-1).toInt()*w+(x+dx).clamp(0,w-1).toInt()]; count++;
        }
      }
      smooth[y*w+x]=total/count;
    }
  }
  final output=img.Image(width: source.width, height: source.height);
  for (var y=0; y<source.height; y++) {
    final sy=y*(h-1)/math.max(1,source.height-1), y0=sy.floor();
    final fy=sy-y0, y1=math.min(y0+1,h-1);
    for (var x=0; x<source.width; x++) {
      final sx=x*(w-1)/math.max(1,source.width-1), x0=sx.floor();
      final fx=sx-x0, x1=math.min(x0+1,w-1);
      final background=(smooth[y0*w+x0]*(1-fx)+smooth[y0*w+x1]*fx)*(1-fy)
        +(smooth[y1*w+x0]*(1-fx)+smooth[y1*w+x1]*fx)*fy;
      final gain=(246/math.max(100,background)).clamp(1.0,2.0);
      final p=source.getPixel(x,y);
      int channel(num value) => ((value*gain-10)*255/238).round().clamp(0,255).toInt();
      output.setPixelRgb(x,y,channel(p.r),channel(p.g),channel(p.b));
    }
  }
  // Mild unsharp mask clarifies strokes without creating hard threshold halos.
  final blur=img.gaussianBlur(img.Image.from(output), radius: 1);
  final sharpened=img.Image(width: output.width, height: output.height);
  for (var y=0; y<output.height; y++) {
    for (var x=0; x<output.width; x++) {
      final p=output.getPixel(x,y), b=blur.getPixel(x,y);
      int sharp(num a,num soft) => (a+.25*(a-soft)).round().clamp(0,255).toInt();
      sharpened.setPixelRgb(x,y,sharp(p.r,b.r),sharp(p.g,b.g),sharp(p.b,b.b));
    }
  }
  return sharpened;
}
