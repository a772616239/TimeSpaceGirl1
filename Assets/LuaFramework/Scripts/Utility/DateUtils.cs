using System;
using GameLogic;
using System.Collections.Generic;

public class DateUtils
{

    public static readonly String DEFAULT_PATTERN = "yyyy-MM-dd HH:mm:ss";
    /// <summary>
    /// 将时间戳转为时间字符串
    /// </summary>
    /// <param name="millis">毫秒时间戳</param>
    /// <param name="format">时间格式</param>
    /// <returns>时间字符串</returns>
    public static String Millis2String(long millis, string format = null)
    {
        DateTime dt = new DateTime(millis);
        if (string.IsNullOrEmpty(format))
            return dt.ToString(DEFAULT_PATTERN);
        else
            return dt.ToString(format);
    }

    /// <summary>
    /// 将时间字符串转为时间戳
    /// </summary>
    /// <param name="time">time格式为yyyy-MM-dd HH:mm:ss的时间字符串</param>
    /// <returns>毫秒时间戳</returns>
    public static long String2Millis(String time)
    {
        return String2Millis(time, DEFAULT_PATTERN);
    }

    /// <summary>
    /// 将时间字符串转为时间戳
    /// </summary>
    /// <param name="time">时间字符串</param>
    /// <param name="pattern">时间格式</param>
    /// <returns>毫秒时间戳</returns>
    public static long String2Millis(String time, String pattern)
    {
        try
        {
            var dt = DateTime.ParseExact(time, pattern, System.Globalization.CultureInfo.CurrentCulture);
            return dt.Ticks;
        }
        catch (Exception e)
        {
            Util.LogError(e.Message);
        }
        return -1;
    }

    public static string GetDateInfo(string timeType, string time, bool isUtc = true)
    {
        DateTime dt = new DateTime();
        if (string.IsNullOrEmpty(time))
        {
            if (isUtc)
                dt = DateTime.UtcNow;
            else
                dt = DateTime.Now;
        }
        else
        {
            dt = DateTime.Parse(time, System.Globalization.CultureInfo.CurrentCulture);
        }
        switch (timeType)
        {
            case "Date":
                return dt.Date.ToString();
            case "DayOfWeek":
                return dt.DayOfWeek.ToString();
            case "DayOfYear":
                return dt.DayOfYear.ToString();
            case "Hour":
                return dt.Hour.ToString();
            case "LongDate":
                return dt.ToLongDateString().ToString();
            case "LocalTime":
                return dt.ToLocalTime().ToString();
            case "Millisecond":
                return dt.Millisecond.ToString();
            case "Minute":
                return dt.Minute.ToString();
            case "Month":
                return dt.Month.ToString();
            case "Second":
                return dt.Second.ToString();
            case "ShortTime":
                return dt.ToShortTimeString();
            case "TimeOfDay":
                return dt.TimeOfDay.ToString();
            case "Ticks":
                return dt.Ticks.ToString();
            case "UniversalTime":
                return dt.ToUniversalTime().ToString();
            case "Year":
                return dt.Year.ToString();
        }
        return null;
    }

    public string DateTimeFormat(long ticks, string format)
    {
        try
        {
            DateTime dt = new DateTime();
            if (ticks == -1)
                dt = DateTime.Now;
            else
                dt = new DateTime(ticks);
            return string.Format(format, dt);
        }
        catch (Exception e)
        {
            Util.LogError(e.Message);
            return null;
        }
    }

    public string DateTimeFormat(string time, string format)
    {
        try
        {
            DateTime dt = new DateTime();
            if (string.IsNullOrEmpty(time))
                dt = DateTime.Now;
            else
                dt = DateTime.Parse(time);
            return string.Format(format, dt);
        }
        catch (Exception e)
        {
            Util.LogError(e.Message);
            return null;
        }
    }

    public int DateTimeCompareTo(string dateTime1, string dateTime2)
    {
        if (string.IsNullOrEmpty(dateTime2))
            return -1;
        if (string.IsNullOrEmpty(dateTime1))
        {
            try
            {
                DateTime dt = DateTime.Parse(dateTime2);
                return DateTime.Now.CompareTo(dt);
            }
            catch (Exception e)
            {
                Util.LogError(e.Message);
                return -1;
            }
        }
        else
        {
            try
            {
                DateTime dt1 = DateTime.Parse(dateTime1);
                DateTime dt2 = DateTime.Parse(dateTime2);
                return dt1.CompareTo(dt2);
            }
            catch (Exception e)
            {
                Util.LogError(e.Message);
                return -1;
            }
        }
        return -1;
    }

    /// <summary>
    /// 获取两个时间差
    /// </summary>
    /// <param name="beginTime">开始时间字符串</param>
    /// <param name="endTime">结束时间字符串</param>
    /// <param name="spanType">时间差值类型</param>
    /// <returns>返回用时间差值格式计算的TimeSpan值</returns>
    public static double GetTimeDoubleInfo(String beginTime, String endTime, string spanType, bool isUtc = false)
    {
        DateTime dateBegin = new DateTime();
        if (string.IsNullOrEmpty(beginTime))
        {
            if (isUtc)
                dateBegin = DateTime.UtcNow;
            else
                dateBegin = DateTime.Now;
        }
        else
            dateBegin = DateTime.Parse(beginTime);
        var dateEnd = new DateTime();
        if (string.IsNullOrEmpty(endTime))
        {
            if (isUtc)
                dateEnd = new System.DateTime(1970, 1, 1, 0, 0, 0, System.DateTimeKind.Utc);
            else
                dateEnd = new System.DateTime(1970, 1, 1, 0, 0, 0, System.DateTimeKind.Local);
        }
        else
        {
            dateEnd = DateTime.Parse(endTime);
        }
        TimeSpan ts1 = new TimeSpan(dateBegin.Ticks);
        TimeSpan ts2 = new TimeSpan(dateEnd.Ticks);
        TimeSpan ts3 = ts1.Subtract(ts2).Duration();
        switch (spanType)
        {
            case "Days":
                return ts3.Days;
            case "Hours":
                return ts3.Hours;
            case "Milliseconds":
                return ts3.Milliseconds;
            case "Minutes":
                return ts3.Minutes;
            case "Seconds":
                return ts3.Seconds;
            case "Ticks":
                return ts3.Ticks;
            case "TotalSeconds":
                var se = ts3.TotalSeconds;
                return se;
            case "TotalDays":
                return ts3.TotalDays;
            case "TotalHours":
                return ts3.TotalHours;
            case "TotalMilliseconds":
                return ts3.TotalMilliseconds;
            case "TotalMinutes":
                return ts3.TotalMinutes;
        }
        return ts3.Milliseconds;
    }

    /// <summary>
    /// 获取两个时间差
    /// </summary>
    /// <param name="beginTime">开始时间字符串</param>
    /// <param name="endTime">结束时间字符串</param>
    /// <param name="spanType">时间差值类型</param>
    /// <returns>返回用时间差值格式计算的TimeSpan值</returns>
    public static long GetTimeIntInfo(String beginTime, String endTime, string spanType, bool isUtc = false)
    {
        DateTime dateBegin = new DateTime();
        if (string.IsNullOrEmpty(beginTime))
        {
            if (isUtc)
                dateBegin = DateTime.UtcNow;
            else
                dateBegin = DateTime.Now;
        }
        else
            dateBegin = DateTime.Parse(beginTime);
        var dateEnd = new DateTime();
        if (string.IsNullOrEmpty(endTime))
        {
            if (isUtc)
                dateEnd = new System.DateTime(1970, 1, 1, 0, 0, 0, System.DateTimeKind.Utc);
            else
                dateEnd = new System.DateTime(1970, 1, 1, 0, 0, 0, System.DateTimeKind.Local);
        }
        else
        {
            dateEnd = DateTime.Parse(endTime);
        }
        TimeSpan ts1 = new TimeSpan(dateBegin.Ticks);
        TimeSpan ts2 = new TimeSpan(dateEnd.Ticks);
        TimeSpan ts3 = ts1.Subtract(ts2).Duration();
        switch (spanType)
        {
            case "Days":
                return ts3.Days;
            case "Hours":
                return ts3.Hours;
            case "Milliseconds":
                return ts3.Milliseconds;
            case "Minutes":
                return ts3.Minutes;
            case "Seconds":
                return ts3.Seconds;
            case "Ticks":
                return ts3.Ticks;
            case "TotalSeconds":
                var se = Convert.ToInt64(ts3.TotalSeconds);
                return se;
            case "TotalDays":
                return Convert.ToInt64(ts3.TotalDays);
            case "TotalHours":
                return Convert.ToInt64(ts3.TotalHours);
            case "TotalMilliseconds":
                return Convert.ToInt64(ts3.TotalMilliseconds);
            case "TotalMinutes":
                return Convert.ToInt64(ts3.TotalMinutes);
        }
        return ts3.Milliseconds;
    }


    /// <summary>
    /// 判断是否闰年
    /// </summary>
    /// <param name="year">年份</param>
    /// <returns>{@code true}: 闰年{@code false}: 平年</returns>

    public static bool IsLeapYear(int year)
    {
        return year % 4 == 0 && year % 100 != 0 || year % 400 == 0;
    }

    private static int GetWeekOfYear(string time)
    {
        DateTime dt = DateTime.Parse(time);
        var gc = new System.Globalization.GregorianCalendar();
        int weekOfYear = gc.GetWeekOfYear(dt, System.Globalization.CalendarWeekRule.FirstDay, DayOfWeek.Monday);
        return weekOfYear;
    }

    private static int GetDateIndex(string time, string dateIndexType)
    {
        DateTime dt = DateTime.Parse(time);
        var gc = new System.Globalization.GregorianCalendar();
        switch (dateIndexType)
        {
            case "DayOfMonth":
                return gc.GetDayOfMonth(dt);
            case "DayOfWeek":
                return (int)gc.GetDayOfWeek(dt);
            case "DayOfYear":
                return gc.GetDayOfYear(dt);
            case "WeekOfYear":
                return gc.GetWeekOfYear(dt, System.Globalization.CalendarWeekRule.FirstDay, DayOfWeek.Monday);
        }
        return -1;
    }

    public int GetWeekOfMonth(string time)
    {
        var date = DateTime.Parse(time);
        DateTime firstDayInMonth = DateTime.Parse(string.Format("{0}-{1}-01", date.Year, date.Month));

        //不计入本月周的总天数，如1号为星期五，则1、2、3都不计入将要计算的周内
        int exceptDays = 0;

        if (firstDayInMonth.DayOfWeek != DayOfWeek.Monday)
        {
            //+ 2的含义为计算时需要减去1号和date当天的日期
            //如果不减去date当天，则当date为星期天时，则刚好在除7后为正确值，再加1就会多一周
            exceptDays = 7 - (int)firstDayInMonth.DayOfWeek + 2;
        }

        //指定的日期减去不计算在周内的日期数
        return (date.Day - exceptDays) / 7 + date.Day < exceptDays ? 0 : 1;
    }

    private static readonly String[] CHINESE_ZODIAC = { "猴", "鸡", "狗", "猪", "鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊" };

    /// <summary>
    /// 获取生肖 
    /// </summary>
    /// <param name="time">时间字符串 time格式为yyyy-MM-dd HH:mm:ss</param>
    /// <returns>生肖</returns>
    public static String getChineseZodiac(String time)
    {
        var date = DateTime.Parse(time);
        return CHINESE_ZODIAC[date.Year % 12];
    }

    /// <summary>
    /// 获取生肖
    /// </summary>
    /// <param name="time">时间字符串</param>
    /// <param name="pattern">时间格式</param>
    /// <returns>生肖</returns>
    public static String getChineseZodiac(String time, String pattern)
    {
        var date = DateTime.ParseExact(time, pattern, System.Globalization.CultureInfo.CurrentCulture);
        return CHINESE_ZODIAC[date.Year % 12];
    }

    private static readonly String[] ZODIAC = { "水瓶座", "双鱼座", "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "魔羯座" };
    private static readonly int[] ZODIAC_FLAGS = { 20, 19, 21, 21, 21, 22, 23, 23, 23, 24, 23, 22 };

    /// <summary>
    /// 获取星座
    /// </summary>
    /// <param name="time">时间字符串 time格式为yyyy-MM-dd HH:mm:ss</param>
    /// <param name="pattern"></param>
    /// <returns>生肖</returns>
    public static String getZodiac(String time, String pattern)
    {
        DateTime dt = new DateTime();
        if (string.IsNullOrEmpty(pattern))
            dt = DateTime.Parse(time);
        else
            dt = DateTime.ParseExact(time, pattern, System.Globalization.CultureInfo.CurrentCulture);
        var gc = new System.Globalization.GregorianCalendar();
        return getZodiac(gc.GetMonth(dt) + 1, gc.GetDayOfMonth(dt));
    }

    /// <summary>
    /// 获取星座
    /// </summary>
    /// <param name="millis">毫秒时间戳</param>
    /// <returns>星座</returns>
    public static String getZodiac(long millis)
    {
        DateTime dt = new DateTime(millis);
        var gc = new System.Globalization.GregorianCalendar();
        return getZodiac(gc.GetMonth(dt) + 1, gc.GetDayOfMonth(dt));
    }

    /// <summary>
    /// 获取星座
    /// </summary>
    /// <param name="month">月</param>
    /// <param name="day">日</param>
    /// <returns>星座</returns>
    public static String getZodiac(int month, int day)
    {
        return ZODIAC[day >= ZODIAC_FLAGS[month - 1] ? month - 1 : (month + 10) % 12];
    }
    /// <summary>
    /// 时分秒倒计时
    /// </summary>
    /// <param name="remainTime"></param>
    /// <returns></returns>
    public static string GetTimeFormat(int remainTime)
    {
        string str = "";
        TimeSpan timeSpan = new TimeSpan(0, 0, remainTime);
        str = string.Format("{0:d2}:{1:d2}:{2:d2}", timeSpan.Hours, timeSpan.Minutes, timeSpan.Seconds);
        return str;
    }
    /// <summary>
    /// 天。小时。分钟
    /// </summary>
    /// <param name="remainTime"></param>
    /// <returns></returns>
    public static string GetTimeFormatV2(int remainTime)
    {
        string str = "";
        TimeSpan timeSpan = new TimeSpan(0, 0, remainTime);
        str = string.Format("{0}天{1}小时{2}分钟", timeSpan.Days, timeSpan.Hours, timeSpan.Minutes);
        return str;
    }
    /// <summary>
    /// 秒时间戳转换成日期
    /// </summary>
    /// <param name="timeStamp"></param>
    /// <returns></returns>
    public static string GetDateTime(int timeStamp)
    {
        DateTime dtStart = TimeZone.CurrentTimeZone.ToLocalTime(new DateTime(1970, 1, 1));
        long lTime = ((long)timeStamp * 10000000);
        TimeSpan toNow = new TimeSpan(lTime);
        DateTime targetDt = dtStart.Add(toNow);
        return targetDt.ToString(DEFAULT_PATTERN);
    }

}
