import js from "@eslint/js";
import tseslint from "typescript-eslint";

const eslintConfig = [
  {
    ignores: [".next/**", "node_modules/**", "src/generated/bible_krv_full.json"]
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      "no-undef": "off",
      "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }]
    }
  }
];

export default eslintConfig;
