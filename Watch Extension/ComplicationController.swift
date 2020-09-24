//
//  ComplicationController.swift
//  Watch Extension
//
//  Created by Nils Bergmann on 19/09/2020.
//

import ClockKit
import Cache

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    var bgUtility: BackgroundUtility = BackgroundUtility();
    
    // MARK: - Complication Configuration

    @available(watchOSApplicationExtension 7.0, *)
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(identifier: "complication", displayName: "Project SITNU", supportedFamilies: CLKComplicationFamily.allCases)
            // Multiple complication support can be added here with more descriptors
        ]
        
        // Call the handler with the currently supported complication descriptors
        handler(descriptors)
    }
    
    @available(watchOSApplicationExtension 7.0, *)
    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do any necessary work to support these newly shared complication descriptors
    }

    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Call the handler with the last entry date you can currently provide or nil if you can't support future timelines
        self.getUntisTimeline(start: getDateWithOffset(for: Date())) { (periods) in
            guard let periods = periods else {
                return handler(nil);
            }
            guard let last = periods.last else {
                return handler(nil);
            }
            handler(last.endTime);
        }
        
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Call the handler with your desired behavior when the device is locked
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let currentDate = Date();
        self.getAllUntisInformation(for: currentDate) {
            handler(nil);
        } handler: { (periods, timegrid, subjects) in
            // If there is currently a period
            if let currentPeriod = periods.first(where: { $0.startTime < currentDate && $0.endTime > currentDate }) {
                let currentEntry = self.getComplicationEntry(for: complication, period: currentPeriod, timegrid: timegrid, subjects: subjects);
                handler(currentEntry);
            } else {
                // It is currently a break
                if let nextPeriodIndex = periods.firstIndex(where: { $0.startTime > currentDate }) {
                    let nextPeriod = periods[nextPeriodIndex];
                    var breakDate = Calendar.current.startOfDay(for: currentDate); // If it is a new timeline
                    if nextPeriodIndex >= 1 {
                        // There is a period before
                        let lastPeriod = periods[nextPeriodIndex - 1]
                        // The start date of the break template is the end date of the last period
                        breakDate = Calendar.current.date(byAdding: .nanosecond, value: 1, to: lastPeriod.endTime)!;
                    }
                    let breakEntry = self.getBreakComplicationEntry(for: complication, date: breakDate, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                    handler(breakEntry);
                } else {
                    // End of timeline
                    let endOfTimelineEntry = self.getTimelineEndEntry(for: complication, and: currentDate);
                    handler(endOfTimelineEntry);
                }
            }
        }

    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        self.getAllUntisInformation(for: date) {
            handler(nil);
        } handler: { (periods, timegrid, subjects) in
            // .filter({ $0.startTime > date || ($0.startTime < date && $0.endTime > date) })
            var entries: [CLKComplicationTimelineEntry] = [];
            var lastEndTime: Date = date;
            
            if let currentPeriod = periods.first(where: { $0.startTime <= date && $0.endTime >= date }) {
                if let nextPeriod = periods.first(where: { $0.startTime >= date && $0.id != currentPeriod.id }) {
                    let n = nextPeriod.startTime.timeIntervalSince1970;
                    let c = currentPeriod.endTime.timeIntervalSince1970;
                    if abs(n - c) <= 1 {
                        // The next entry is the next period
                        let nextEntry = self.getComplicationEntry(for: complication, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                        entries.appendWithLimitCheck(limit, item: nextEntry!);
                    } else {
                        // We need to add a break entry
                        let nextEntry = self.getBreakComplicationEntry(for: complication, date: currentPeriod.endTime, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                        entries.appendWithLimitCheck(limit, item: nextEntry!);
                        let nextPeriodEntry = self.getComplicationEntry(for: complication, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                        entries.appendWithLimitCheck(limit, item: nextPeriodEntry!);
                    }
                    // Every next period needs to be after this time
                    lastEndTime = nextPeriod.endTime;
                } else {
                    // No next Period. The next entry is the end of the timeline
                    let endEntry = self.getTimelineEndEntry(for: complication, and: date);
                    entries.appendWithLimitCheck(limit, item: endEntry!);
                    // We don't need to add anything anymore. We can just return.
                    return handler(entries);
                }
            } else {
                if let nextPeriod = periods.first(where: { $0.startTime >= date }) {
                    // New Timeline
                    let nextEntry = self.getBreakComplicationEntry(for: complication, date: lastEndTime, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                    entries.appendWithLimitCheck(limit, item: nextEntry!);
                    let nextPeriodEntry = self.getComplicationEntry(for: complication, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                    entries.appendWithLimitCheck(limit, item: nextPeriodEntry!);
                    lastEndTime = nextPeriod.endTime;
                } else {
                    // No next Period. The next entry is the end of the timeline
                    let endEntry = self.getTimelineEndEntry(for: complication, and: date);
                    entries.appendWithLimitCheck(limit, item: endEntry!);
                    // We don't need to add anything anymore. We can just return.
                    return handler(entries);
                }
            }
            
            while (true) {
                if let nextPeriod = periods.first(where: { $0.startTime >= lastEndTime }) {
                    let n = nextPeriod.startTime.timeIntervalSince1970;
                    let c = lastEndTime.timeIntervalSince1970;
                    if abs(n - c) <= 1 {
                        // We don't need a break entry
                        let nextEntry = self.getComplicationEntry(for: complication, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                        entries.appendWithLimitCheck(limit, item: nextEntry!);
                    } else {
                        // We need to add a break entry, because there is time between last period and next period
                        let breakEntry = self.getBreakComplicationEntry(for: complication, date: lastEndTime, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                        entries.appendWithLimitCheck(limit, item: breakEntry!);
                        let nextPeriodEntry = self.getComplicationEntry(for: complication, period: nextPeriod, timegrid: timegrid, subjects: subjects);
                        entries.appendWithLimitCheck(limit, item: nextPeriodEntry!);
                    }
                    lastEndTime = nextPeriod.endTime;
                } else {
                    // There is no next period. This is the end of timeline
                    let endEntry = self.getTimelineEndEntry(for: complication, and: lastEndTime);
                    entries.appendWithLimitCheck(limit, item: endEntry!);
                    break;
                }
                
                if entries.count >= limit {
                    // We can't add anything anymore
                    break;
                }
            }
            return handler(entries);
        }
    }

    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        handler(nil)
    }
    
    // MARK: Entry generators
    
    func getBreakComplicationEntry(for complication: CLKComplication, date: Date, period: Period, timegrid: Timegrid, subjects: [Subject]) -> CLKComplicationTimelineEntry? {
        var template: CLKComplicationTemplate?;
        
        switch complication.family {
        case .modularLarge:
            var title = "Next";
            if period.subjects.count > 0 {
                title = "Next: \(UntisUtil.default.getSubtypeListString(subTypes: period.subjects))"
            }
            let titleColor = UntisUtil.default.getColor(for: period, subjects: subjects);
            let titleTextProvider = CLKSimpleTextProvider(text: title);
            if let uiColor = UIColor(hex: titleColor.description) {
                titleTextProvider.tintColor = uiColor;
            }
            var subTitle = "";
            if period.rooms.count > 0 && period.teachers.count > 0 {
                subTitle = "In \(UntisUtil.default.getSubtypeListString(subTypes: period.rooms)) by \(UntisUtil.default.getSubtypeListString(subTypes: period.teachers))"
            } else if period.rooms.count > 0 {
                subTitle = "In \(UntisUtil.default.getSubtypeListString(subTypes: period.rooms))"
            } else if period.teachers.count > 0 {
                subTitle = "By \(UntisUtil.default.getSubtypeListString(subTypes: period.teachers))"
            } else {
                subTitle = "-";
            }
            let subTitleTextProvider = CLKSimpleTextProvider(text: subTitle);
            let relativeTextProvder = CLKRelativeDateTextProvider(date: period.startTime, style: .timer, units: [.hour, .minute, .second]);
            let localTemplate = CLKComplicationTemplateModularLargeStandardBody()
            localTemplate.headerTextProvider = titleTextProvider;
            localTemplate.body1TextProvider = subTitleTextProvider;
            localTemplate.body2TextProvider = relativeTextProvder;
            template = localTemplate;
            break;
        @unknown default:
            return nil;
        }
        
        if template != nil {
            return CLKComplicationTimelineEntry(date: Calendar.current.date(byAdding: .nanosecond, value: 1, to: date)!, complicationTemplate: template!)
        }
        return nil;
    }
    
    func getComplicationEntry(for complication: CLKComplication, period: Period, timegrid: Timegrid, subjects: [Subject]) -> CLKComplicationTimelineEntry? {
        var template: CLKComplicationTemplate?;
        
        switch complication.family {
        case .modularLarge:
            let title = UntisUtil.default.getRowTitle(period: period, timegrid: timegrid);
            let titleColor = UntisUtil.default.getColor(for: period, subjects: subjects);
            let titleTextProvider = CLKSimpleTextProvider(text: title);
            if let uiColor = UIColor(hex: titleColor.description) {
                titleTextProvider.tintColor = uiColor;
            }
            var subTitle = "";
            if period.rooms.count > 0 && period.teachers.count > 0 {
                subTitle = "In \(UntisUtil.default.getSubtypeListString(subTypes: period.rooms)) by \(UntisUtil.default.getSubtypeListString(subTypes: period.teachers))"
            } else if period.rooms.count > 0 {
                subTitle = "In \(UntisUtil.default.getSubtypeListString(subTypes: period.rooms))"
            } else if period.teachers.count > 0 {
                subTitle = "By \(UntisUtil.default.getSubtypeListString(subTypes: period.teachers))"
            } else {
                subTitle = "-";
            }
            let subTitleTextProvider = CLKSimpleTextProvider(text: subTitle);
            let relativeTextProvder = CLKRelativeDateTextProvider(date: period.endTime, style: .timer, units: [.hour, .minute, .second]);
            let localTemplate = CLKComplicationTemplateModularLargeStandardBody()
            localTemplate.headerTextProvider = titleTextProvider;
            localTemplate.body1TextProvider = subTitleTextProvider;
            localTemplate.body2TextProvider = relativeTextProvder;
            template = localTemplate;
            break;
        @unknown default:
            return nil;
        }
        if template != nil {
            return CLKComplicationTimelineEntry(date: Calendar.current.date(byAdding: .nanosecond, value: 1, to: period.startTime)!, complicationTemplate: template!)
        }
        return nil;
    }
    
    func getTimelineEndEntry(for complication: CLKComplication, and date: Date) -> CLKComplicationTimelineEntry? {
        var template: CLKComplicationTemplate?;
        
        switch complication.family {
        case .modularLarge:
            let title = "End of Timeline";
            let titleColor: UIColor = .yellow;
            let titleTextProvider = CLKSimpleTextProvider(text: title);
            titleTextProvider.tintColor = titleColor;
            let subTitleTextProvider = CLKSimpleTextProvider(text: "You did it!");
            let localTemplate = CLKComplicationTemplateModularLargeStandardBody()
            localTemplate.headerTextProvider = titleTextProvider;
            localTemplate.body1TextProvider = subTitleTextProvider;
            template = localTemplate;
            break;
        @unknown default:
            return nil;
        }
        
        if template != nil {
            return CLKComplicationTimelineEntry(date: Calendar.current.date(byAdding: .nanosecond, value: 1, to: date)!, complicationTemplate: template!)
        }
        return nil;
    }
    
    // MARK: Untis functions
    
    func getUntisTimeline(start date: Date, handler: @escaping ([Period]?) -> Void) {
        guard let untis = self.bgUtility.getUntisClient() else {
            return handler(nil);
        }
        untis.getTimetable(for: getFetchDate(date: date), cachedHandler: nil) { result in
            var periods: [Period] = [];
            guard let currentPeriods = try? result.get() else {
                return handler(nil);
            }
            periods.append(contentsOf: currentPeriods);
            untis.getTimetable(for: Calendar.current.date(byAdding: .day, value: 1, to: getFetchDate(date: date))!, cachedHandler: nil) { tomorrowResult in
                guard let tomorrowPeriods = try? tomorrowResult.get() else {
                    return handler(nil);
                }
                periods.append(contentsOf: tomorrowPeriods);
                if periods.count < 1 {
                    return handler(nil);
                }
                let sorted = periods
                                .sortedPeriods(useEndtime: true)
                                .filter({ $0.code != .cancelled });
                
                handler(sorted);
            }
        }
    }
    
    func getTimegrid(handler: @escaping (Timegrid?) -> Void) {
        guard let untis = self.bgUtility.getUntisClient() else {
            return handler(nil);
        }
        untis.getTimegrid(cachedHandler: nil) { result in
            guard let timegrid = try? result.get() else {
                return handler(nil);
            }
            handler(timegrid);
        }
    }
    
    func getSubjects(handler: @escaping ([Subject]?) -> Void) {
        guard let untis = self.bgUtility.getUntisClient() else {
            return handler(nil);
        }
        untis.getSubjectColors(cachedHandler: nil) { result in
            guard let subjects = try? result.get() else {
                return handler(nil);
            }
            handler(subjects);
        }
    }
    
    func getAllUntisInformation(for date: Date, failedHandler: @escaping () -> Void, handler: @escaping ([Period], Timegrid, [Subject]) -> Void) {
        self.getTimegrid { timegrid in
            guard let timegrid = timegrid else {
                return failedHandler();
            }
            self.getSubjects { subjects in
                guard let subjects = subjects else {
                    return failedHandler();
                }
                self.getUntisTimeline(start: date) { (periods) in
                    guard let periods = periods else {
                        return failedHandler();
                    }
                    handler(periods, timegrid, subjects);
                }
            }
        }
    }
}

extension Array where Element == CLKComplicationTimelineEntry {
    
    mutating func appendWithLimitCheck(_ limit: Int, item: CLKComplicationTimelineEntry) {
        if self.count < limit {
            self.append(item);
        }
    }
    
}
