String describeDocumentError(Object error) {
  final text = error.toString();

  if (text.contains('仅支持 Markdown 和 HTML')) {
    return '仅支持 .md、.markdown、.html、.htm 文档';
  }
  if (text.contains('不存在') ||
      text.contains('已被移') ||
      text.contains('No such file')) {
    return '文档已被移动或删除，请重新导入';
  }
  if (text.contains('权限') ||
      text.contains('Permission') ||
      text.contains('denied')) {
    return '无法继续访问该文档，请重新授权或重新导入';
  }
  if (text.contains('同名文档已存在')) {
    return '同名文档已存在，请换一个名称';
  }
  if (text.contains('系统文件选择器没有返回') ||
      text.contains('系统没有传入可读取')) {
    return '系统没有返回可读取的文档，请重新选择';
  }

  return '操作失败：$error';
}
