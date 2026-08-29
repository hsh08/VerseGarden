import type { CommunityFormValues } from "@/types/community";

type Props = {
  values: CommunityFormValues;
  onChange: (values: CommunityFormValues) => void;
  disabled?: boolean;
};

export function CommunityForm({ values, onChange, disabled = false }: Props) {
  return (
    <div className="community-form-grid">
      <div className="field-block">
        <label htmlFor="community-name">공동체 이름</label>
        <input
          id="community-name"
          className="input"
          value={values.name}
          disabled={disabled}
          placeholder="예: 새봄교회 청년 공동체"
          onChange={(event) => onChange({ ...values, name: event.target.value })}
        />
      </div>

      <div className="field-block">
        <label htmlFor="community-timezone">시간대</label>
        <select
          id="community-timezone"
          className="input"
          value={values.timezone}
          disabled={disabled}
          onChange={(event) => onChange({ ...values, timezone: event.target.value })}
        >
          <option value="Asia/Seoul">Asia/Seoul</option>
          <option value="America/New_York">America/New_York</option>
          <option value="America/Los_Angeles">America/Los_Angeles</option>
          <option value="Europe/London">Europe/London</option>
        </select>
      </div>

      <div className="field-block community-form-wide">
        <label htmlFor="community-description">설명</label>
        <textarea
          id="community-description"
          className="textarea"
          value={values.description}
          disabled={disabled}
          placeholder="공동체를 구분할 수 있는 짧은 설명을 입력하세요."
          onChange={(event) => onChange({ ...values, description: event.target.value })}
        />
      </div>

      <label className="toggle-row community-form-wide">
        <input
          type="checkbox"
          checked={values.inviteEnabled}
          disabled={disabled}
          onChange={(event) => onChange({ ...values, inviteEnabled: event.target.checked })}
        />
        <span>
          <strong>초대 허용</strong>
          <small>활성 공동체에서 새 초대 코드를 만들 수 있습니다.</small>
        </span>
      </label>
    </div>
  );
}
