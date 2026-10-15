import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.075, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let mint = NSColor(calibratedRed: 0.48, green: 0.96, blue: 0.77, alpha: 1)
let muted = NSColor(calibratedRed: 0.25, green: 0.32, blue: 0.37, alpha: 1)
for index in 0..<4 {
    let x = CGFloat(126 + index * 202)
    let on = index == 1 || index == 3
    let rect = NSRect(x:x,y:292,width:166,height:424)
    let path = NSBezierPath(roundedRect:rect,xRadius:52,yRadius:52)
    NSColor(calibratedRed:0.10,green:0.14,blue:0.17,alpha:1).setFill()
    path.fill()
    (on ? mint : muted).setStroke()
    path.lineWidth=6
    path.stroke()
    (on ? mint : muted).setFill()
    NSBezierPath(ovalIn:NSRect(x:x+61,y:620,width:44,height:44)).fill()
    let value = on ? "1" : "0"
    let attributes:[NSAttributedString.Key:Any] = [.font:NSFont.monospacedSystemFont(ofSize:132,weight:.semibold),.foregroundColor:on ? mint : muted]
    value.draw(at:NSPoint(x:x+43,y:400),withAttributes:attributes)
}
let line=NSBezierPath()
line.move(to:NSPoint(x:190,y:218));line.line(to:NSPoint(x:834,y:218))
NSColor(calibratedRed:1,green:0.74,blue:0.39,alpha:1).setStroke();line.lineWidth=10;line.lineCapStyle = .round;line.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
let data=bitmap.representation(using:.png,properties:[:])!
try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
