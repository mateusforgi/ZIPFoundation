//
//  ZIPFoundationWritingTests.swift
//  ZIPFoundation
//
//  Copyright © 2017-2023 Thomas Zoechling, https://www.peakstep.com and the ZIP Foundation project authors.
//  Released under the MIT License.
//
//  See https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE for license information.
//

import XCTest
@testable import ZIPFoundation

extension ZIPFoundationTests {

    func testCreateArchiveAddUncompressedEntry() {
        let archive = self.archive(for: #function, mode: .create)
        let assetURL = self.resourceURL(for: #function, pathExtension: "png")
        do {
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
        } catch {
            XCTFail("Failed to add uncompressed entry archive with error : \(error)")
        }
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddCompressedEntry() {
        let archive = self.archive(for: #function, mode: .create)
        let assetURL = self.resourceURL(for: #function, pathExtension: "png")
        do {
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL, compressionMethod: .deflate)
        } catch {
            XCTFail("Failed to add compressed entry folder archive : \(error)")
        }
        let entry = archive[assetURL.lastPathComponent]
        XCTAssertNotNil(entry)
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddDirectory() {
        let archive = self.archive(for: #function, mode: .create)
        do {
            try archive.addEntry(with: "Test", type: .directory,
                                 uncompressedSize: Int64(0), provider: { _, _ in return Data()})
        } catch {
            XCTFail("Failed to add directory entry without file system representation to archive.")
        }
        let testEntry = archive["Test"]
        XCTAssertNotNil(testEntry)
        let uniqueString = ProcessInfo.processInfo.globallyUniqueString
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uniqueString)
        do {
            let fileManager = FileManager()
            try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            let relativePath = tempDirectoryURL.lastPathComponent
            let baseURL = tempDirectoryURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath + "/", relativeTo: baseURL)
        } catch {
            XCTFail("Failed to add directory entry to archive.")
        }
        let entry = archive[tempDirectoryURL.lastPathComponent + "/"]
        XCTAssertNotNil(entry)
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddSymbolicLink() {
        let archive = self.archive(for: #function, mode: .create)
        let rootDirectoryURL = ZIPFoundationTests.tempZipDirectoryURL.appendingPathComponent("SymbolicLinkDirectory")
        let symbolicLinkURL = rootDirectoryURL.appendingPathComponent("test.link")
        let assetURL = self.resourceURL(for: #function, pathExtension: "png")
        let fileManager = FileManager()
        do {
            try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createSymbolicLink(atPath: symbolicLinkURL.path, withDestinationPath: assetURL.path)
            let relativePath = symbolicLinkURL.lastPathComponent
            let baseURL = symbolicLinkURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
        } catch {
            XCTFail("Failed to add symbolic link to archive")
        }
        let entry = archive[symbolicLinkURL.lastPathComponent]
        XCTAssertNotNil(entry)
        XCTAssert(archive.checkIntegrity())
        do {
            try archive.addEntry(with: "link", type: .symlink, uncompressedSize: Int64(10),
                                 provider: { (_, count) -> Data in
                return Data(count: count)
            })
        } catch {
            XCTFail("Failed to add symbolic link to archive")
        }
        let entry2 = archive["link"]
        XCTAssertNotNil(entry2)
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddEntryErrorConditions() {
        var didCatchExpectedError = false
        let archive = self.archive(for: #function, mode: .create)
        let tempPath = NSTemporaryDirectory()
        var nonExistantURL = URL(fileURLWithPath: tempPath)
        nonExistantURL.appendPathComponent("invalid.path")
        let nonExistantRelativePath = nonExistantURL.lastPathComponent
        let nonExistantBaseURL = nonExistantURL.deletingLastPathComponent()
        do {
            try archive.addEntry(with: nonExistantRelativePath, relativeTo: nonExistantBaseURL)
        } catch let error as CocoaError {
            XCTAssert(error.code == .fileReadNoSuchFile)
            didCatchExpectedError = true
        } catch {
            XCTFail("Unexpected error while trying to add non-existant file to an archive.")
        }
        XCTAssertTrue(didCatchExpectedError)
        // Cover the error code path when `fopen` fails during entry addition.
        let assetURL = self.resourceURL(for: #function, pathExtension: "txt")
        self.runWithFileDescriptorLimit(0) {
            do {
                let relativePath = assetURL.lastPathComponent
                let baseURL = assetURL.deletingLastPathComponent()
                try archive.addEntry(with: relativePath, relativeTo: baseURL)
            } catch {
                didCatchExpectedError = true
            }
        }
        XCTAssertTrue(didCatchExpectedError)
    }

    func testArchiveAddEntryErrorConditions() {
        var didCatchExpectedError = false
        let readonlyArchive = self.archive(for: #function, mode: .read)
        do {
            try readonlyArchive.addEntry(with: "Test", type: .directory,
                                         uncompressedSize: Int64(0), provider: { _, _ in return Data()})
        } catch let error as Archive.ArchiveError {
            XCTAssert(error == .unwritableArchive)
            didCatchExpectedError = true
        } catch {
            XCTFail("Unexpected error while trying to add an entry to a readonly archive.")
        }
        XCTAssertTrue(didCatchExpectedError)
    }

    func testCreateArchiveAddZeroSizeUncompressedEntry() {
        let archive = self.archive(for: #function, mode: .create)
        let assetURL = self.resourceURL(for: #function, pathExtension: "txt")
        do {
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL)
        } catch {
            XCTFail("Failed to add zero-size uncompressed entry to archive with error : \(error)")
        }
        let entry = archive[assetURL.lastPathComponent]
        XCTAssertNotNil(entry)
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddZeroSizeCompressedEntry() {
        let archive = self.archive(for: #function, mode: .create)
        let assetURL = self.resourceURL(for: #function, pathExtension: "txt")
        do {
            let relativePath = assetURL.lastPathComponent
            let baseURL = assetURL.deletingLastPathComponent()
            try archive.addEntry(with: relativePath, relativeTo: baseURL, compressionMethod: .deflate)
        } catch {
            XCTFail("Failed to add zero-size compressed entry to archive with error : \(error)")
        }
        let entry = archive[assetURL.lastPathComponent]
        XCTAssertNotNil(entry)
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddLargeUncompressedEntry() {
        let archive = self.archive(for: #function, mode: .create)
        let size = 1024*1024*20
        let data = Data.makeRandomData(size: size)
        let entryName = ProcessInfo.processInfo.globallyUniqueString
        do {
            try archive.addEntry(with: entryName, type: .file,
                                 uncompressedSize: Int64(size), provider: { (position, bufferSize) -> Data in
                                    let upperBound = Swift.min(size, Int(position) + bufferSize)
                                    let range = Range(uncheckedBounds: (lower: Int(position), upper: upperBound))
                                    return data.subdata(in: range)
            })
        } catch {
            XCTFail("Failed to add large entry to uncompressed archive with error : \(error)")
        }
        guard let entry = archive[entryName] else {
            XCTFail("Failed to add large entry to uncompressed archive")
            return
        }
        XCTAssert(entry.checksum == data.crc32(checksum: 0))
        XCTAssert(archive.checkIntegrity())
    }

    func testCreateArchiveAddLargeCompressedEntry() {
        let archive = self.archive(for: #function, mode: .create)
        let size = 1024*1024*20
        let data = Data.makeRandomData(size: size)
        let entryName = ProcessInfo.processInfo.globallyUniqueString
        do {
            try archive.addEntry(with: entryName, type: .file, uncompressedSize: Int64(size),
                                 compressionMethod: .deflate,
                                 provider: { (position, bufferSize) -> Data in
                                    let upperBound = Swift.min(size, Int(position) + bufferSize)
                                    let range = Range(uncheckedBounds: (lower: Int(position), upper: upperBound))
                                    return data.subdata(in: range)
            })
        } catch {
            XCTFail("Failed to add large entry to compressed archive with error : \(error)")
        }
        guard let entry = archive[entryName] else {
            XCTFail("Failed to add large entry to compressed archive")
            return
        }
        let dataCRC32 = data.crc32(checksum: 0)
        XCTAssert(entry.checksum == dataCRC32)
        XCTAssert(archive.checkIntegrity())
    }

    func testRemoveUncompressedEntry() {
        let archive = self.archive(for: #function, mode: .update)
        guard let entryToRemove = archive["test/data.random"] else {
            XCTFail("Failed to find entry to remove in uncompressed folder"); return
        }
        do {
            try archive.remove(entryToRemove)
        } catch {
            XCTFail("Failed to remove entry from uncompressed folder archive with error : \(error)")
        }
        XCTAssert(archive.checkIntegrity())
    }

    func testRemoveCompressedEntry() {
        let archive = self.archive(for: #function, mode: .update)
        guard let entryToRemove = archive["test/data.random"] else {
            XCTFail("Failed to find entry to remove in compressed folder archive"); return
        }
        do {
            try archive.remove(entryToRemove)
        } catch {
            XCTFail("Failed to remove entry from compressed folder archive with error : \(error)")
        }
        XCTAssert(archive.checkIntegrity())
    }

    func testRemoveDataDescriptorCompressedEntry() {
        let archive = self.archive(for: #function, mode: .update)
        guard let entryToRemove = archive["second.txt"] else {
            XCTFail("Failed to find entry to remove in compressed folder archive")
            return
        }
        do {
            try archive.remove(entryToRemove)
        } catch {
            XCTFail("Failed to remove entry to compressed folder archive with error : \(error)")
        }
        XCTAssert(archive.checkIntegrity())
    }

    func testRemoveEntryErrorConditions() {
        var didCatchExpectedError = false
        let archive = self.archive(for: #function, mode: .update)
        guard let entryToRemove = archive["test/data.random"] else {
            XCTFail("Failed to find entry to remove in uncompressed folder")
            return
        }
        // We don't have access to the temp archive file that Archive.remove
        // uses. To exercise the error code path, we temporarily limit the number of open files for
        // the test process to exercise the error code path here.
        self.runWithFileDescriptorLimit(0) {
            do {
                try archive.remove(entryToRemove)
            } catch let error as Archive.ArchiveError {
                XCTAssertNotNil(error == .unwritableArchive)
                didCatchExpectedError = true
            } catch {
                XCTFail("Unexpected error while trying to remove entry from unwritable archive.")
            }
        }
        XCTAssertTrue(didCatchExpectedError)
        didCatchExpectedError = false
        let readonlyArchive = self.archive(for: #function, mode: .read)
        do {
            try readonlyArchive.remove(entryToRemove)
        } catch let error as Archive.ArchiveError {
            XCTAssertNotNil(error == .unwritableArchive)
            didCatchExpectedError = true
        } catch {
            XCTFail("Unexpected error while trying to remove entry from readonly archive.")
        }
        XCTAssertTrue(didCatchExpectedError)
    }

    func testArchiveCreateErrorConditions() {
        let existantURL = ZIPFoundationTests.tempZipDirectoryURL
        let nonCreatableArchive = Archive(url: existantURL, accessMode: .create)
        XCTAssertNil(nonCreatableArchive)
        let processInfo = ProcessInfo.processInfo
        var noEndOfCentralDirectoryArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        noEndOfCentralDirectoryArchiveURL.appendPathComponent(processInfo.globallyUniqueString)
        let fullPermissionAttributes = [FileAttributeKey.posixPermissions: NSNumber(value: defaultFilePermissions)]
        let fileManager = FileManager()
        let result = fileManager.createFile(atPath: noEndOfCentralDirectoryArchiveURL.path, contents: nil,
                                                    attributes: fullPermissionAttributes)
        XCTAssert(result == true)
        let noEndOfCentralDirectoryArchive = Archive(url: noEndOfCentralDirectoryArchiveURL,
                                                     accessMode: .update)
        XCTAssertNil(noEndOfCentralDirectoryArchive)
    }

    func testArchiveUpdateErrorConditions() {
        var nonUpdatableArchiveURL = ZIPFoundationTests.tempZipDirectoryURL
        let processInfo = ProcessInfo.processInfo
        nonUpdatableArchiveURL.appendPathComponent(processInfo.globallyUniqueString)
        let noPermissionAttributes = [FileAttributeKey.posixPermissions: NSNumber(value: Int16(0o000))]
        let fileManager = FileManager()
        let result = fileManager.createFile(atPath: nonUpdatableArchiveURL.path, contents: nil,
                                            attributes: noPermissionAttributes)
        XCTAssert(result == true)
        let nonUpdatableArchive = Archive(url: nonUpdatableArchiveURL, accessMode: .update)
        XCTAssertNil(nonUpdatableArchive)
    }

    func testReplaceCurrentArchiveWithArchiveCrossLink() {
		#if os(macOS)
        let createVolumeExpectation = expectation(description: "Creation of temporary additional volume")
        let unmountVolumeExpectation = expectation(description: "Unmount temporary additional volume")
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            let volName = "Test_\(UUID().uuidString)"
            let task = try NSUserScriptTask.makeVolumeCreationTask(at: tempDir, volumeName: volName)
            task.execute { (error) in
                guard error == nil else {
                    XCTFail("\(String(describing: error))")
                    return
                }
                let vol2URL = URL(fileURLWithPath: "/Volumes/\(volName)")
                defer {
                    FileManager.default.unmountVolume(at: vol2URL, options:
                        [.allPartitionsAndEjectDisk, .withoutUI], completionHandler: { (error) in
                            guard error == nil else {
                                XCTFail("\(String(describing: error))")
                                return
                            }
                            unmountVolumeExpectation.fulfill()
                    })
                }
                let vol1ArchiveURL = tempDir.appendingPathComponent("vol1Archive")
                let vol2ArchiveURL = vol2URL.appendingPathComponent("vol2Archive")
                guard let vol1Archive = Archive(url: vol1ArchiveURL, accessMode: .create),
                    let vol2Archive = Archive(url: vol2ArchiveURL, accessMode: .create) else {
                    XCTFail("Failed to create test archive '\(vol2ArchiveURL)'")
                    type(of: self).tearDown()
                    return
                }

                do {
                    try vol1Archive.replaceCurrentArchive(with: vol2Archive)
                } catch {
                    XCTFail("\(String(describing: error))")
                    return
                }
                createVolumeExpectation.fulfill()
            }
        } catch {
            XCTFail("\(error)")
            return
        }
        defer { try? FileManager.default.removeItem(at: tempDir) }

        waitForExpectations(timeout: 30.0)
		#endif
    }
}
