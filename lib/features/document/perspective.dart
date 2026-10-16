import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'edge_detector.dart';

/// Maps the unit output square to the detected source quadrilateral with a
/// projective homography, so perspective-slanted text lines remain straight.
class DocumentHomography {
  DocumentHomography(DocumentQuad quad) {
    final p=quad.points;
    final dx1=p[1].x-p[2].x, dx2=p[3].x-p[2].x;
    final dy1=p[1].y-p[2].y, dy2=p[3].y-p[2].y;
    final dx3=p[0].x-p[1].x+p[2].x-p[3].x;
    final dy3=p[0].y-p[1].y+p[2].y-p[3].y;
    if (dx3.abs()+dy3.abs() > 1e-10) {
      final det=dx1*dy2-dx2*dy1;
      if (det.abs()<1e-10) throw const FormatException('Invalid document corners');
      g=(dx3*dy2-dx2*dy3)/det;
      h=(dx1*dy3-dx3*dy1)/det;
    }
    a=p[1].x-p[0].x+g*p[1].x;
    b=p[3].x-p[0].x+h*p[3].x;
    c=p[0].x;
    d=p[1].y-p[0].y+g*p[1].y;
    e=p[3].y-p[0].y+h*p[3].y;
    f=p[0].y;
  }
  late final double a,b,c,d,e,f;
  double g=0,h=0;
  math.Point<double> map(double u,double v) {
    final divisor=g*u+h*v+1;
    if (divisor.abs()<1e-10) throw const FormatException('Invalid document perspective');
    return math.Point((a*u+b*v+c)/divisor,(d*u+e*v+f)/divisor);
  }
}

img.Image rectifyDocument(img.Image source, DocumentQuad quad, int width, int height) {
  final transform=DocumentHomography(quad);
  final output=img.Image(width:width,height:height);
  for (var y=0;y<height;y++) {
    for (var x=0;x<width;x++) {
      final p=transform.map(x/(width-1),y/(height-1));
      final sx=(p.x*(source.width-1)).clamp(0.0,(source.width-1).toDouble()).toDouble();
      final sy=(p.y*(source.height-1)).clamp(0.0,(source.height-1).toDouble()).toDouble();
      output.setPixel(x,y,source.getPixelInterpolate(sx,sy,interpolation:img.Interpolation.linear));
    }
  }
  return output;
}
