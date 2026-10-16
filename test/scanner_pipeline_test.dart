import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_scanner/features/document/edge_detector.dart';
import 'package:pdf_scanner/features/document/page_processing.dart';
import 'package:pdf_scanner/features/document/perspective.dart';

Uint8List pageFrame(int w, int h, List<Point<double>> corners, int ink, int paper) {
  final frame=Uint8List(w*h)..fillRange(0,w*h,ink);
  for (var y=0; y<h; y++) {
    for (var x=0; x<w; x++) {
      var inside=true;
      for (var i=0; i<4; i++) {
        final a=corners[i], b=corners[(i+1)%4];
        if ((b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x)<0) inside=false;
      }
      if (inside) frame[y*w+x]=paper;
    }
  }
  return frame;
}

void main() {
  test('adaptive edges recover a dim perspective page', () {
    const points=[Point(60.0,30.0),Point(207.0,70.0),Point(180.0,280.0),Point(25.0,230.0)];
    final gray=pageFrame(240,320,points,90,115);
    final result=detectDocument({'gray':gray,'width':240,'height':320});
    expect(result,isNotNull);
    for (var i=0;i<4;i++) {
      expect(result!.points[i].x,closeTo(points[i].x/239,.04));
      expect(result.points[i].y,closeTo(points[i].y/319,.04));
    }
  });

  test('uniform bright or dark frames cannot invent a page', () {
    for (final light in [0,110,255]) {
      final gray=Uint8List(240*320)..fillRange(0,240*320,light);
      expect(detectDocument({'gray':gray,'width':240,'height':320}),isNull);
    }
  });

  test('focus loss blocks capture but does not re-arm a captured page', () {
    const q=DocumentQuad([Point(.1,.1),Point(.9,.1),Point(.9,.9),Point(.1,.9)]);
    final gate=AutoCaptureGate(), now=DateTime(2026);
    gate.update(q,now);
    expect(gate.update(q,now.add(const Duration(seconds: 2)),ready:false),isFalse);
    expect(gate.update(q,now.add(const Duration(seconds: 3))),isFalse);
    expect(gate.update(q,now.add(const Duration(milliseconds: 4200))),isTrue);
    gate.captured();
    for (var i=5;i<9;i++) { gate.update(q,now.add(Duration(seconds:i)),ready:false); }
    expect(gate.awaitingRemoval,isTrue);
    expect(gate.update(q,now.add(const Duration(seconds: 10))),isFalse);
    gate.reset(clearRemoval:true);
    expect(gate.update(q,now.add(const Duration(seconds: 11))),isFalse);
  });

  test('enhancement evens lighting, retains dark text and preserves color order', () {
    final source=img.Image(width:120,height:160);
    for (var y=0;y<160;y++) {
      for (var x=0;x<120;x++) {
        final v=170+(50*x/119).round(); source.setPixelRgb(x,y,v,v,v);
      }
    }
    for (var y=70;y<80;y++) {
      for (var x=40;x<70;x++) { source.setPixelRgb(x,y,25,25,25); }
    }
    for (var y=95;y<115;y++) {
      for (var x=85;x<105;x++) { source.setPixelRgb(x,y,20,80,140); }
    }
    final input=Uint8List.fromList(img.encodePng(source));
    final output=img.decodeImage(processPage({'bytes':input,'enhance':true}))!;
    final left=output.getPixel(10,20).r, right=output.getPixel(110,20).r;
    expect(left,greaterThan(220));
    expect((left-right).abs(),lessThan(25));
    expect(output.getPixel(55,75).r,lessThan(90));
    final stamp=output.getPixel(95,105);
    expect(stamp.b,greaterThan(stamp.g));
    expect(stamp.g,greaterThan(stamp.r));
    final unchanged=img.decodeImage(processPage({'bytes':input}))!;
    expect(unchanged.getPixel(10,20).r,lessThan(190));
  });
  test('perspective mapping matches corners and converging page geometry', () {
    const q=DocumentQuad([Point(.2,.1),Point(.8,.1),Point(.95,.9),Point(.05,.9)]);
    final transform=DocumentHomography(q);
    const unit=[Point(0.0,0.0),Point(1.0,0.0),Point(1.0,1.0),Point(0.0,1.0)];
    for (var i=0;i<4;i++) {
      expect(transform.map(unit[i].x,unit[i].y).distanceTo(q.points[i]),lessThan(1e-8));
    }
    expect(transform.map(.5,.5).x,closeTo(.5,1e-8));
    // A true projective mapping differs from the old bilinear midpoint (.5,.5).
    expect(transform.map(.5,.5).y,lessThan(.49));
  });

}
