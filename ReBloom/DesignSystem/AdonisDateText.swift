import Foundation

enum AdonisDateText {
  static func longDate(_ date: Date) -> String {
    format(date, dateStyle: .long, timeStyle: .none)
  }

  static func dateAndTime(_ date: Date) -> String {
    format(date, dateStyle: .long, timeStyle: .short)
  }

  static func eventTime(_ date: Date) -> String {
    format(date, dateStyle: .short, timeStyle: .medium)
  }

  private static func format(
    _ date: Date,
    dateStyle: DateFormatter.Style,
    timeStyle: DateFormatter.Style
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
    return formatter.string(from: date)
  }
}
