~/.rbenv/versions/2.2.3/bin/jekyll build

git add .
git commit -m 'update'
git push -u origin master &

cp -r _site/* ../qwert42.github.io/

cd ../qwert42.github.io
git add .
git commit -m 'update'
git push -u origin master &


