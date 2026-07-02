import SwiftUI

struct DSTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
}

struct DSTabBar: View {
    let items: [DSTabItem]
    @Binding var selection: DSTabItem.ID

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(items) { item in
                Button {
                    withAnimation(AppMotion.smooth) {
                        selection = item.id
                    }
                } label: {
                    VStack(spacing: AppSpacing.xxs) {
                        Image(systemName: item.systemImage)
                            .font(.subheadline.weight(.semibold))

                        Text(item.title)
                            .font(AppTypography.captionStrong)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == item.id ? Color.ds.accentPrimary : Color.ds.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selection == item.id ? Color.ds.accentSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.xs)
        .glassSurface(cornerRadius: AppRadius.tabBar)
        .shadow(color: Color.ds.shadowTint.opacity(AppShadow.elevatedOpacity), radius: AppShadow.elevatedRadius, x: 0, y: AppShadow.elevatedY)
    }
}
