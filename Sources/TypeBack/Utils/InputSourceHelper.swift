import Carbon
import Foundation

/// 输入法管理错误
enum InputSourceError: Error {
    case noEnglishInputSourceFound
    case noChineseInputSourceFound
    case switchFailed
    case permissionDenied
}

/// 输入法助手 - 优化版
/// 管理 macOS 输入法切换
final class InputSourceHelper: @unchecked Sendable {

    // MARK: - 缓存
    private var cachedEnglishSourceID: String?
    private var cachedChineseSourceIDs: [String] = []
    private var cacheLock = NSLock()
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 30

    // MARK: - 初始化
    init() {
        refreshCache()
    }

    // MARK: - 公共方法

    /// 检查当前输入法是否是英文
    func isCurrentInputSourceEnglish() -> Bool {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }
        return isKeyboardLayout(source: current)
    }

    /// 获取当前输入法简称
    func getCurrentBriefName() -> String {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return "?"
        }
        return isKeyboardLayout(source: current) ? "EN" : "中"
    }

    /// 切换到英文输入法
    @discardableResult
    func switchToEnglish() -> Bool {
        // 如果已经是英文，直接返回
        if isCurrentInputSourceEnglish() {
            return true
        }

        // 尝试获取缓存的英文输入法
        if let cachedID = getCachedEnglishSourceID(),
           let cachedSource = findInputSource(byID: cachedID),
           activateInputSource(cachedSource) {
                return true
        }

        // 缓存失效，重新查找
        refreshCache()

        guard let englishSource = findBestEnglishSource() else {
            print("InputSourceHelper: 未找到英文输入法")
            return false
        }

        if let sourceID = getInputSourceID(englishSource) {
            cacheEnglishSourceID(sourceID)
        }
        return activateInputSource(englishSource)
    }

    /// 切换到中文输入法
    @discardableResult
    func switchToChinese() -> Bool {
        // 如果已经是中文，直接返回
        if !isCurrentInputSourceEnglish() {
            return true
        }

        // 尝试使用缓存的中文输入法
        let cachedIDs = getCachedChineseSourceIDs()
        for sourceID in cachedIDs {
            guard let source = findInputSource(byID: sourceID) else { continue }
            if activateInputSource(source) {
                return true
            }
        }

        // 缓存失效，重新查找
        refreshCache()

        guard let chineseSource = findBestChineseSource() else {
            print("InputSourceHelper: 未找到中文输入法")
            return false
        }

        return activateInputSource(chineseSource)
    }

    // MARK: - 缓存管理

    private func refreshCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        // 检查缓存是否仍然有效
        if let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            return
        }

        // 清空缓存
        cachedEnglishSourceID = nil
        cachedChineseSourceIDs = []

        // 预加载所有输入法
        let allSources = getAllInputSources()

        for source in allSources {
            guard isInputSourceEnabled(source),
                  isInputSourceSelectable(source) else { continue }

            if isKeyboardLayout(source: source) {
                // 英文输入法
                if cachedEnglishSourceID == nil && isEnglishLayout(source) {
                    cachedEnglishSourceID = getInputSourceID(source)
                }
            } else if isInputMethod(source: source) {
                // 中文输入法
                if let sourceID = getInputSourceID(source) {
                    cachedChineseSourceIDs.append(sourceID)
                }
            }
        }

        lastCacheUpdate = Date()
    }

    private func getCachedEnglishSourceID() -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedEnglishSourceID
    }

    private func getCachedChineseSourceIDs() -> [String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedChineseSourceIDs
    }

    private func cacheEnglishSourceID(_ sourceID: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedEnglishSourceID = sourceID
    }

    // MARK: - 查找方法

    private func findBestEnglishSource() -> TISInputSource? {
        let allSources = getAllInputSources()

        // 优先查找 ABC
        if let abc = allSources.first(where: { source in
            guard isKeyboardLayout(source: source),
                  isInputSourceEnabled(source),
                  isInputSourceSelectable(source) else { return false }
            let id = getInputSourceID(source) ?? ""
            return id.contains("ABC")
        }) {
            return abc
        }

        // 其次查找 US 或 British
        return allSources.first { source in
            guard isKeyboardLayout(source: source),
                  isInputSourceEnabled(source),
                  isInputSourceSelectable(source) else { return false }
            let id = getInputSourceID(source) ?? ""
            return id.contains("US") || id.contains("British")
        }
    }

    private func findBestChineseSource() -> TISInputSource? {
        let allSources = getAllInputSources()

        return allSources.first { source in
            isInputMethod(source: source) &&
            isInputSourceEnabled(source) &&
            isInputSourceSelectable(source)
        }
    }

    // MARK: - 辅助方法

    private func getAllInputSources() -> [TISInputSource] {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return sources
    }

    private func activateInputSource(_ source: TISInputSource) -> Bool {
        let result = TISSelectInputSource(source)
        return result == noErr
    }

    private func findInputSource(byID sourceID: String) -> TISInputSource? {
        getAllInputSources().first { getInputSourceID($0) == sourceID }
    }

    // MARK: - 属性获取

    private func getInputSourceID(_ source: TISInputSource) -> String? {
        stringProperty(for: source, key: kTISPropertyInputSourceID)
    }

    private func isKeyboardLayout(source: TISInputSource) -> Bool {
        guard let type = stringProperty(for: source, key: kTISPropertyInputSourceType) else { return false }
        return type == kTISTypeKeyboardLayout as String
    }

    private func isInputMethod(source: TISInputSource) -> Bool {
        guard let type = stringProperty(for: source, key: kTISPropertyInputSourceType) else { return false }
        return type == kTISTypeKeyboardInputMode as String || type == "InputMethod"
    }

    private func isInputSourceEnabled(_ source: TISInputSource) -> Bool {
        boolProperty(for: source, key: kTISPropertyInputSourceIsEnabled)
    }

    private func isInputSourceSelectable(_ source: TISInputSource) -> Bool {
        boolProperty(for: source, key: kTISPropertyInputSourceIsSelectCapable)
    }

    private func isEnglishLayout(_ source: TISInputSource) -> Bool {
        let id = getInputSourceID(source) ?? ""
        return id.contains("ABC") || id.contains("US") || id.contains("British")
    }

    private func stringProperty(for source: TISInputSource, key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        let cfValue = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        guard CFGetTypeID(cfValue) == CFStringGetTypeID() else { return nil }
        return (cfValue as! CFString) as String
    }

    private func boolProperty(for source: TISInputSource, key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        let cfValue = Unmanaged<CFTypeRef>.fromOpaque(raw).takeUnretainedValue()
        guard CFGetTypeID(cfValue) == CFBooleanGetTypeID() else { return false }
        return CFBooleanGetValue((cfValue as! CFBoolean))
    }
}
