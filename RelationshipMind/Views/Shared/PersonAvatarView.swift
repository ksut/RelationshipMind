import SwiftUI

struct PersonAvatarView: View {
    let person: Person
    let size: CGFloat

    var body: some View {
        Group {
            if let photoData = person.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(person.initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: size, height: size)
                    .background(avatarColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var avatarColor: Color {
        // Generate a consistent color based on the person's name
        let name = person.displayName
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.7)
    }
}

#Preview {
    HStack(spacing: 16) {
        PersonAvatarView(
            person: Person(firstName: "John", lastName: "Doe"),
            size: 40
        )
        PersonAvatarView(
            person: Person(firstName: "Alice", lastName: "Smith"),
            size: 60
        )
        PersonAvatarView(
            person: Person(firstName: "Bob", lastName: ""),
            size: 80
        )
    }
    .padding()
}
