import Cocoa

class NoteTableCellView: NSTableCellView {
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let previewLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tagsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 10)
        label.textColor = .systemBlue
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(previewLabel)
        addSubview(tagsLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            previewLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            previewLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            tagsLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            tagsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            tagsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            tagsLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }

    func configure(with note: Note) {
        titleLabel.stringValue = note.title
        previewLabel.stringValue = note.preview
        let tagsString = note.tags.sorted().joined(separator: " ")
        tagsLabel.stringValue = tagsString
        tagsLabel.isHidden = tagsString.isEmpty
    }
}
