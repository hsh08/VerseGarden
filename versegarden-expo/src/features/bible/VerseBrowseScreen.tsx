import { useMemo, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";

import { VGScreen } from "@/components/layout/VGScreen";
import { VGCard, VGEmptyStateView, VGSectionHeader } from "@/components/ui";
import type { BibleBook, BibleVerse } from "./bibleTypes";
import { VerseRow } from "./VerseRow";
import { useBibleRepository } from "./useBibleRepository";
import { useBibleSearch } from "./useBibleSearch";
import { colors, radius, spacing, typography } from "@/theme/tokens";

type BrowseStep = "books" | "chapters" | "verses";
const searchResultLimit = 12;

export function VerseBrowseScreen() {
  const router = useRouter();
  const { repository, error } = useBibleRepository();
  const [query, setQuery] = useState("");
  const [step, setStep] = useState<BrowseStep>("books");
  const [selectedBook, setSelectedBook] = useState<BibleBook | null>(null);
  const [selectedChapter, setSelectedChapter] = useState<number | null>(null);
  const search = useBibleSearch(repository, query, searchResultLimit);
  const chapters = selectedBook ? repository?.getChapters(selectedBook.name) ?? [] : [];
  const verses = selectedBook && selectedChapter ? repository?.getVerses(selectedBook.name, selectedChapter) ?? [] : [];
  const isSearching = query.trim().length > 0;
  const books = useMemo(() => repository?.getBooks() ?? [], [repository]);

  const openVerse = (verse: BibleVerse) => {
    router.push({ pathname: "/verse/[verseId]", params: { verseId: verse.id } });
  };

  const goBack = () => {
    if (step === "verses") {
      setSelectedChapter(null);
      setStep("chapters");
      return;
    }
    if (step === "chapters") {
      setSelectedBook(null);
      setStep("books");
    }
  };

  if (error) {
    return <VGScreen><VGEmptyStateView description="성경 데이터를 준비하지 못했습니다. 앱을 다시 시작한 뒤 시도해주세요." title="말씀을 불러올 수 없어요" /></VGScreen>;
  }

  if (!repository) {
    return <VGScreen><View style={styles.loading}><ActivityIndicator color={colors.forestGreen} /><Text style={styles.loadingText}>성경 본문을 준비하고 있어요.</Text></View></VGScreen>;
  }

  return (
    <VGScreen>
      <View style={styles.header}>
        <Text style={styles.title}>말씀</Text>
        <Text style={styles.subtitle}>성경을 읽고 마음에 남는 구절을 찾아보세요.</Text>
        <View style={styles.headerActions}><Pressable accessibilityRole="button" onPress={() => router.push("/verse/saved")} style={styles.headerAction}><Text style={styles.headerActionText}>저장한 말씀</Text></Pressable><Pressable accessibilityRole="button" onPress={() => router.push("/verse/lists")} style={styles.headerAction}><Text style={styles.headerActionText}>리스트</Text></Pressable><Pressable accessibilityRole="button" onPress={() => router.push("/verse/plans")} style={styles.headerAction}><Text style={styles.headerActionText}>필사 플랜</Text></Pressable></View>
      </View>

      <VGCard style={styles.searchCard} tinted>
        <Text style={styles.searchLabel}>말씀 검색</Text>
        <TextInput
          accessibilityLabel="말씀 검색"
          autoCapitalize="none"
          autoCorrect={false}
          clearButtonMode="while-editing"
          onChangeText={setQuery}
          placeholder="예: 사랑, 창세기 1:1"
          placeholderTextColor={colors.subtleText}
          style={styles.searchInput}
          value={query}
        />
        {isSearching ? <Text style={styles.searchHelper}>{search.isSearching ? "말씀을 찾는 중이에요." : `${search.verses.length}개 결과를 찾았어요.`}</Text> : null}
      </VGCard>

      {isSearching ? (
        <View style={styles.section}>
          {search.isSearching ? <View style={styles.searching}><ActivityIndicator color={colors.forestGreen} /><Text style={styles.searchingText}>검색 중</Text></View> : null}
          {!search.isSearching && search.verses.length === 0 ? <VGEmptyStateView description="다른 단어나 책 이름으로 다시 검색해보세요." title="검색 결과가 없어요" /> : null}
          {!search.isSearching && search.verses.length > 0 ? <View style={styles.list}>{search.verses.map((verse) => <VerseRow key={verse.id} onPress={openVerse} verse={verse} />)}</View> : null}
          {search.hasMoreResults ? <Text style={styles.moreResults}>더 많은 결과가 있습니다. 검색어를 더 구체적으로 입력해보세요.</Text> : null}
        </View>
      ) : (
        <View style={styles.section}>
          {step !== "books" ? <Pressable accessibilityRole="button" onPress={goBack} style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}><Text style={styles.backLabel}>‹ 이전</Text></Pressable> : null}
          {step === "books" ? <BookPicker books={books} onSelect={(book) => { setSelectedBook(book); setStep("chapters"); }} /> : null}
          {step === "chapters" && selectedBook ? <ChapterPicker book={selectedBook} chapters={chapters} onSelect={(chapter) => { setSelectedChapter(chapter); setStep("verses"); }} /> : null}
          {step === "verses" && selectedBook && selectedChapter ? <VerseList book={selectedBook} chapter={selectedChapter} onPress={openVerse} verses={verses} /> : null}
        </View>
      )}
    </VGScreen>
  );
}

function BookPicker({ books, onSelect }: { books: readonly BibleBook[]; onSelect: (book: BibleBook) => void }) {
  const oldTestament = books.filter((book) => book.testament === "old");
  const newTestament = books.filter((book) => book.testament === "new");
  return <View style={styles.section}><VGSectionHeader description="책을 선택해 장과 절을 차례로 살펴볼 수 있어요." title="성경 읽기" /><BookSection books={oldTestament} onSelect={onSelect} title="구약" /><BookSection books={newTestament} onSelect={onSelect} title="신약" /></View>;
}

function BookSection({ books, onSelect, title }: { books: readonly BibleBook[]; onSelect: (book: BibleBook) => void; title: string }) {
  return <View style={styles.bookSection}><Text style={styles.sectionTitle}>{title}</Text><View style={styles.grid}>{books.map((book) => <Pressable accessibilityLabel={`${book.name} 선택`} accessibilityRole="button" key={book.name} onPress={() => onSelect(book)} style={({ pressed }) => [styles.gridItem, pressed && styles.pressed]}><Text style={styles.gridItemLabel}>{book.name}</Text></Pressable>)}</View></View>;
}

function ChapterPicker({ book, chapters, onSelect }: { book: BibleBook; chapters: readonly number[]; onSelect: (chapter: number) => void }) {
  return <View style={styles.section}><VGSectionHeader description={`${book.name}의 장을 선택하세요.`} title={book.name} /><View style={styles.grid}>{chapters.map((chapter) => <Pressable accessibilityLabel={`${book.name} ${chapter}장 선택`} accessibilityRole="button" key={chapter} onPress={() => onSelect(chapter)} style={({ pressed }) => [styles.gridItem, pressed && styles.pressed]}><Text style={styles.gridItemLabel}>{chapter}장</Text></Pressable>)}</View></View>;
}

function VerseList({ book, chapter, verses, onPress }: { book: BibleBook; chapter: number; verses: readonly BibleVerse[]; onPress: (verse: BibleVerse) => void }) {
  return <View style={styles.section}><VGSectionHeader description="절을 눌러 전체 말씀을 읽을 수 있어요." title={`${book.name} ${chapter}장`} /><View style={styles.list}>{verses.map((verse) => <VerseRow key={verse.id} onPress={onPress} verse={verse} />)}</View></View>;
}

const styles = StyleSheet.create({
  loading: { alignItems: "center", flex: 1, gap: spacing.sm, justifyContent: "center" },
  loadingText: { color: colors.secondaryText, ...typography.body },
  header: { gap: spacing.xxs },
  title: { color: colors.primaryText, ...typography.display },
  subtitle: { color: colors.secondaryText, ...typography.body },
  headerActions: { flexDirection: "row", flexWrap: "wrap", gap: spacing.xs, marginTop: spacing.xs },
  headerAction: { backgroundColor: colors.cardTint, borderColor: colors.border, borderRadius: radius.pill, borderWidth: 1, minHeight: 40, justifyContent: "center", paddingHorizontal: spacing.sm },
  headerActionText: { color: colors.forestGreen, ...typography.label },
  searchCard: { gap: spacing.sm, padding: spacing.md },
  searchLabel: { color: colors.forestGreen, ...typography.label },
  searchInput: { backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.medium, borderWidth: 1, color: colors.primaryText, minHeight: 50, paddingHorizontal: spacing.md, ...typography.body },
  searchHelper: { color: colors.secondaryText, ...typography.caption },
  section: { gap: spacing.md },
  searching: { alignItems: "center", flexDirection: "row", gap: spacing.xs, paddingVertical: spacing.md },
  searchingText: { color: colors.secondaryText, ...typography.caption },
  list: { gap: spacing.sm },
  moreResults: { color: colors.secondaryText, ...typography.caption },
  backButton: { alignSelf: "flex-start", minHeight: 44, justifyContent: "center", paddingHorizontal: spacing.xs },
  backLabel: { color: colors.forestGreen, ...typography.bodyEmphasis },
  bookSection: { gap: spacing.sm },
  sectionTitle: { color: colors.primaryText, ...typography.heading },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: spacing.xs },
  gridItem: { alignItems: "center", backgroundColor: colors.cardBackground, borderColor: colors.border, borderRadius: radius.small, borderWidth: 1, justifyContent: "center", minHeight: 48, minWidth: 74, paddingHorizontal: spacing.sm },
  gridItemLabel: { color: colors.deepGreen, ...typography.label },
  pressed: { opacity: 0.72 },
});
