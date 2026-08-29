import Image from "next/image";

type AdminBrandMode = "platform" | "community" | "leader";

const modeLabels: Record<AdminBrandMode, string> = {
  platform: "Platform Admin",
  community: "Community Admin",
  leader: "Community Leader"
};

export function AdminBrand({ mode }: { mode: AdminBrandMode }) {
  return (
    <div className="brand-block">
      <Image
        className="brand-icon"
        src="/brand/versegarden-app-icon.png"
        alt="VerseGarden"
        width={48}
        height={48}
        priority
      />
      <div className="brand-copy">
        <span className="brand-title">VerseGarden</span>
        <span className="brand-subtitle">{modeLabels[mode]}</span>
      </div>
    </div>
  );
}
