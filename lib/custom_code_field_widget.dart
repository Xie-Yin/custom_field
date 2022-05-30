import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

/*
 * 项目名:    custom_field
 * 包名:      
 * 文件名:    custom_code_field_widget
 * 创建时间:  2022/5/30 on 15:15
 * 描述:     自定义验证码｜密码输入框
 *
 * @author   azhon
 */

class CustomCodeFieldWidget extends StatefulWidget {
  ///输入的字符最大长度
  final int maxLength;

  ///输入框高度
  final double fieldHeight;

  ///选中的色调
  final Color primaryColor;

  ///选中的
  final Color normalColor;

  ///光标的大小
  final Size indicatorSize;

  ///光标绘制的偏移量
  final Offset indicatorOffset;

  ///文本样式
  final TextStyle textStyle;

  ///每个字符间距
  final double spaceWidth;

  ///输入完成监听
  final ValueChanged<String>? onDone;

  const CustomCodeFieldWidget({
    Key? key,
    this.maxLength = 6,
    this.fieldHeight = 33,
    this.spaceWidth = 12,
    this.onDone,
    this.indicatorSize = const Size(2, 20),
    this.indicatorOffset = const Offset(0, 7),
    this.primaryColor = const Color(0xFFFF443D),
    this.normalColor = const Color(0xFFDBDFE6),
    this.textStyle = const TextStyle(color: Color(0xFF393C42), fontSize: 28),
  }) : super(key: key);

  @override
  _CustomCodeFieldWidgetState createState() => _CustomCodeFieldWidgetState();
}

class _CustomCodeFieldWidgetState extends State<CustomCodeFieldWidget>
    with WidgetsBindingObserver {
  ///焦点控制
  final FocusNode _focusNode = FocusNode();

  ///当前输入的内容
  String _inputCode = '';

  ///用来控制光标闪烁
  int _cursorValue = 0;

  ///用来控制光标闪烁
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controlFocus(true);
  }

  ///控制焦点
  void _controlFocus(bool focus) {
    if (focus) {
      _focusNode.requestFocus();
      _startCursorTimer();
    } else {
      _focusNode.unfocus();
      _cancelCursorTimer();
    }
  }

  ///开启光标动画
  void _startCursorTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        _cursorValue += 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () => _controlFocus(true),
          child: SizedBox(
            height: widget.fieldHeight,
            child: Stack(
              children: [
                _buildField(),
                Container(color: Colors.white, width: constraints.maxWidth),
                CustomPaint(
                  size: Size(constraints.maxWidth, widget.fieldHeight),
                  painter: _CodeInputPainter(widget, _inputCode, _cursorValue),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField() {
    return IgnorePointer(
      child: SizedBox(
        width: 1,
        child: TextField(
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: widget.maxLength,
          onChanged: (text) {
            setState(() {
              _inputCode = text;
            });
            if (text.length >= widget.maxLength) {
              _controlFocus(false);
              widget.onDone?.call(text);
            }
          },
        ),
      ),
    );
  }

  ///取消光标动画
  void _cancelCursorTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelCursorTimer();
    _focusNode.dispose();
    super.dispose();
  }
}

class _CodeInputPainter extends CustomPainter {
  final CustomCodeFieldWidget widget;

  final String code;
  final int cursorValue;
  late Size lineSize;
  late Paint _paint;

  _CodeInputPainter(this.widget, this.code, this.cursorValue) {
    _paint = Paint();
    _paint.color = widget.primaryColor;
    _paint.strokeJoin = StrokeJoin.round;
  }

  _calcLineWidth(Size size) {
    var width = size.width - ((widget.maxLength - 1) * widget.spaceWidth);
    lineSize = Size(width / widget.maxLength, 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _calcLineWidth(size);
    _drawUnderLine(canvas, size);
    _drawIndicator(canvas, size);
    _drawText(canvas, size);
  }

  ///绘制下划线
  void _drawUnderLine(Canvas canvas, Size size) {
    for (var i = 0; i < widget.maxLength; i++) {
      _paint.color =
          code.length == i ? widget.primaryColor : widget.normalColor;
      var rect = Rect.fromLTWH(
        (lineSize.width + widget.spaceWidth) * i,
        size.height,
        lineSize.width,
        lineSize.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(lineSize.height)),
        _paint,
      );
    }
  }

  ///绘制光标,没有焦点不需要显示光标
  void _drawIndicator(Canvas canvas, Size size) {
    if (cursorValue.isOdd) {
      return;
    }
    _paint.color = widget.primaryColor;
    var inputLength = code.length;
    if (inputLength == widget.maxLength) return;
    var start =
        (lineSize.width + widget.spaceWidth) * inputLength + lineSize.width / 2;
    var rect = Rect.fromLTWH(
      start + widget.indicatorOffset.dx,
      widget.indicatorOffset.dy,
      widget.indicatorSize.width,
      widget.indicatorSize.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect, Radius.circular(widget.indicatorSize.width)),
      _paint,
    );
  }

  ///绘制文本
  void _drawText(Canvas canvas, Size size) {
    var list = code.split("");
    for (var i = 0; i < list.length; i++) {
      ///计算文字开始的位置
      var start = (lineSize.width + widget.spaceWidth) * i;

      var builder = ui.ParagraphBuilder(_convertTextStyle(widget.textStyle))
        ..pushStyle(ui.TextStyle(color: widget.textStyle.color))
        ..addText(list[i]);
      var pc = ui.ParagraphConstraints(width: size.width);
      var paragraph = builder.build()..layout(pc);
      var textSize = _calcTextSize(list[i]);

      ///计算文字的中心位置
      start = start + lineSize.width / 2 - textSize.width / 2;
      canvas.drawParagraph(paragraph, Offset(start, 0));
    }
  }

  ///计算文字所占大小
  Size _calcTextSize(String text) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: widget.textStyle,
        ),
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  ui.ParagraphStyle _convertTextStyle(TextStyle style) {
    return ui.ParagraphStyle(
      fontSize: style.fontSize,
      fontStyle: style.fontStyle,
      fontWeight: style.fontWeight,
      height: style.height,
      fontFamily: style.fontFamily,
    );
  }

  @override
  bool shouldRepaint(_CodeInputPainter oldDelegate) {
    return oldDelegate.code != code || oldDelegate.cursorValue != cursorValue;
  }
}
